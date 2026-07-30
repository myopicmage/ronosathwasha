#!/usr/bin/env bash
#
# Serve build/ and expose it through a public cloudflared quick tunnel.
#
#     ./scripts/share.sh [port]        # or: make share [PORT=...]
#
# Two processes, because cloudflared cannot serve files: `--url` proxies to a
# local webserver and `--hello-world` is a demo origin, so something has to be
# listening before the tunnel is worth opening.
#
# This lives in a script rather than in the Makefile recipe because make runs
# every recipe line in its own shell, so orchestrating two processes there is
# one long backslash-continued line with no room for the two things below.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

port="${1:-8000}"

if ! command -v cloudflared >/dev/null 2>&1; then
  if [[ -n "${RONOSATHWASHA_RESHELLED:-}" ]]; then
    echo "cloudflared missing even inside the dev shell." >&2
    exit 1
  fi
  echo "Entering the dev shell..."
  RONOSATHWASHA_RESHELLED=1 exec nix develop 'path:.' --command "$0" "$@"
fi

if [[ ! -f build/dictionary.html && ! -f build/basic-sentences.html ]]; then
  echo "build/ has no pages. Run 'make site' first." >&2
  exit 1
fi

# Refuse a port something else already holds. Not a courtesy: if our server
# cannot bind, it exits, the poll below still gets an answer from whatever is
# already there, and the tunnel goes up in front of somebody else's service.
# The whole point of this script is to publish one specific directory, so the
# port has to be ours before anything is exposed.
#
# Deliberately no SO_REUSEADDR on the probe. On BSD and macOS that option is
# what *permits* binding a port another socket already holds, so setting it
# here turns the check into one that can never fail.
if ! python3 -c "
import socket, sys

# The same address http.server binds, or a wildcard listener elsewhere would
# not collide with a probe on the loopback alone.
s = socket.socket()
try:
    s.bind(('0.0.0.0', $port))
except OSError:
    sys.exit(1)
finally:
    s.close()
"; then
  echo "Something is already listening on port $port." >&2
  echo "Stop it, or pick another: make share PORT=8001" >&2
  exit 1
fi

# Job control, so the server becomes its own process group leader and the trap
# can take its children with it. Without this the server shares this script's
# group, and killing that group would kill the script mid-cleanup.
set -m

# stdout is request logging and is noise; stderr is where a failure to bind
# would appear, so it stays visible.
python3 -m http.server -d build "$port" >/dev/null &
server=$!

cleanup() {
  kill -- "-$server" 2>/dev/null || kill "$server" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Poll rather than sleep. A fixed wait is a race the other way: if the server is
# slow to bind, cloudflared attaches to nothing and the tunnel serves 502s to
# whoever you just sent the link to, which reads as a broken page rather than a
# broken tunnel. Liveness is checked before the request, so a server that died
# is reported as dead rather than as slow.
echo "Waiting for the server on port $port..."
ready=""
for _ in $(seq 1 100); do
  if ! kill -0 "$server" 2>/dev/null; then
    echo "The server exited instead of starting. Its error is above." >&2
    exit 1
  fi

  if curl -sf -o /dev/null "http://localhost:$port/"; then
    ready=yes
    break
  fi

  sleep 0.1
done

if [[ -z "$ready" ]]; then
  echo "The server never answered on port $port." >&2
  exit 1
fi

# Belt and braces. The probe above closes its socket before the server opens
# one, so a listener arriving in that window would still have been missed, and
# the answer to the poll would have come from it rather than from us.
if ! kill -0 "$server" 2>/dev/null; then
  echo "The port answered but our server is gone, so the answer came from" >&2
  echo "something else. Refusing to put a tunnel in front of it." >&2
  exit 1
fi

echo
echo "Serving build/ at http://localhost:$port"
echo "A quick tunnel is public: anyone with the URL below can read build/"
echo "until you stop this with Ctrl-C. The URL is the only thing gating it."
echo

cloudflared tunnel --url "http://localhost:$port"
