#!/usr/bin/env bash
#
# Start llama-server for one conversation, then run Lauri's terminal session.
#
#     ./scripts/chat-all.sh            # or: make chat-all
#
# `make chat` assumes a server is already running and is the right target when
# one is. This owns a server for exactly one conversation and takes it down
# afterwards, which is two processes with a lifetime between them.
#
# That lifetime is why this is a script. Make runs every recipe line in its own
# shell, so a recipe holding a PID across a poll has to be one backslash-joined
# line, and the trap that stops the server from outliving the conversation only
# covers what stayed inside it. Dropping one backslash silently splits the
# shell, empties the PID and leaves a fourteen-gigabyte process running.
#
# Every knob below is read from the environment, so `make chat-all PORT=...`
# style overrides still arrive: make puts command-line variables into a recipe's
# environment, and a plain `VAR=x ./scripts/chat-all.sh` works the same way.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

url="${CHAT_SERVER_URL:-http://127.0.0.1:8080}"
port="${CHAT_SERVER_PORT:-8080}"
wait_seconds="${CHAT_SERVER_WAIT:-120}"

# The weights stay outside the repository, and AGENTS.md carries the argument:
# `nix develop 'path:.'` copies this whole tree into the nix store on every
# evaluation without consulting git, so a ten-gigabyte file in here would be
# copied on every make.
#
# `config/chatbot.toml` names the same file for the Raku side, which reads it
# to report what it is talking to. Two declarations of one path, and the reason
# they have not been collapsed is that collapsing them means parsing TOML in
# bash to learn something this script only needs in order to exec a binary.
model="${CHAT_MODEL_PATH:-$HOME/models/Qwen3-14B-Q5_K_M.gguf}"

# Raku names a module repository by a spec rather than a path, and zef cannot
# install into rakudo's own because it lives in the read-only nix store. So the
# distribution's dependencies sit in a project-local one that every Raku command
# has to name.
#
# The `#` needs no escaping here, which is the whole difference from the
# Makefile. There it opens a comment even inside a quoted assignment, and the
# escape that fixes it in a variable assignment breaks it in a recipe, so the
# spec has to be built once and passed around. In bash it is just a character
# inside single quotes.
export RAKULIB='inst#.raku'

# Same probe as the Makefile's, one tool per half of what this target needs.
# Checking only one of them lets a direnv shell cached from before the other
# arrived pass the test while missing half the toolchain.
if ! { command -v llama-server && command -v raku; } >/dev/null 2>&1; then
  if [[ -n "${RONOSATHWASHA_RESHELLED:-}" ]]; then
    echo "llama-server or raku missing even inside the dev shell." >&2
    exit 1
  fi
  echo "Entering the dev shell..."
  RONOSATHWASHA_RESHELLED=1 exec nix develop 'path:.' --command "$0" "$@"
fi

# A server somebody else started is theirs. Attaching to it is the point of
# `make chat`, and taking it down when this conversation ends would be rude to
# whatever started it, so ownership is decided once, here, and the trap is only
# installed on the branch that created a process.
if curl -fsS --max-time 1 "$url/health" >/dev/null 2>&1; then
  echo "Using llama-server at $url"
else
  echo "Starting llama-server on port $port"

  llama-server --model "$model" --jinja --port "$port" &
  server=$!

  cleanup() {
    kill "$server" >/dev/null 2>&1 || true
    wait "$server" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT INT TERM

  # Poll rather than sleep, and check liveness before each probe. Loading a
  # fourteen-billion-parameter model takes about twelve seconds on this machine
  # and rather longer on a cold page cache, so a fixed wait is either too short
  # to be reliable or long enough to be irritating every single time.
  #
  # The liveness check is the half that matters. Without it a server that died
  # on startup, because the weights are missing or the port is held, is
  # indistinguishable from one that is merely slow, and the failure arrives
  # `$wait_seconds` later as a timeout rather than immediately as its own error.
  ready=""
  for _ in $(seq 1 "$wait_seconds"); do
    if curl -fsS --max-time 1 "$url/health" >/dev/null 2>&1; then
      ready=yes
      break
    fi

    if ! kill -0 "$server" >/dev/null 2>&1; then
      if wait "$server"; then status=0; else status=$?; fi
      echo "llama-server exited before becoming healthy (status $status)" >&2
      exit "$status"
    fi

    sleep 1
  done

  if [[ -z "$ready" ]]; then
    echo "llama-server did not become healthy after $wait_seconds seconds" >&2
    exit 1
  fi
fi

# Pay the prompt's cold cost here, where something is already waiting, rather
# than on the first message, where somebody is.
#
# The system message is around 1700 tokens and llama-server keeps the longest
# common prefix per slot, so the first turn of a session costs about fourteen
# seconds of prompt evaluation and every turn after it costs the handful of
# tokens it added. Moving that one payment in front of the prompt turns a
# fourteen-second greeting into a startup that was already slow for other
# reasons.
#
# Unconditional, including when attaching to a server somebody else started,
# because a running server has whatever prefix its last conversation left and
# there is no reason to assume it is this one. Warming an already-warm cache
# costs about a second.
#
# Failure is deliberately not fatal. A cold cache is slower, not broken, and
# refusing to open a conversation over a missed optimisation would cost more
# than the optimisation was worth.
echo "Warming the prompt cache..."
bin/ronosathwasha-chat --warm || true

# Not exec. Replacing this shell would discard the trap along with it, and the
# server would outlive the conversation it was started for.
bin/ronosathwasha-chat "$@"
