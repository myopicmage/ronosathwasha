# Everything worth running, and what each thing is actually made from.
#
#     make            list the targets
#     make site       build everything servable into build/
#     make share      serve build/ through a public cloudflared tunnel
#
# The targets that produce a file are declared against that file rather than
# marked phony, so nothing recompiles a font to serve a page that has not
# changed. Only the verbs below are phony.

PORT ?= 8000

# Empty under direnv, which is the usual case: the toolchain is already on
# PATH. Outside it, every recipe re-enters the dev shell, the way
# scripts/install.sh does. `path:.` copies the working tree into the store on
# each evaluation, so avoid writing into it from elsewhere while this runs.
RESHELL := $(shell command -v fontmake >/dev/null 2>&1 || echo "nix develop 'path:.' --command")
PY := $(RESHELL) python3

MODEL := $(wildcard ronesathwasha/*.py)
SCRIPT := data/script.toml
LEXICON := data/lexicon.toml

# The declaration plus everything that turns it into outlines. Any of these
# moving changes the shapes, so anything carrying a font is out of date.
UFO := $(MODEL) $(SCRIPT) sources/strokes.py tools/build_ufo.py
WEB := $(UFO) tools/webfont.py

FONT := build/Ronesathwasha.ttf
DICTIONARY := build/dictionary.html
KEYLAYOUT := layouts/Ronesathwasha.keylayout
PAGES := $(wildcard docs/*.html)

# build_docs writes one file per page from a single run. A stamp is how make
# expresses "these outputs, one command", without claiming each page is built
# independently.
STAMP := build/.docs.stamp

.DEFAULT_GOAL := help

.PHONY: help all site font dict pages keylayout serve share test typecheck check install clean

help: ## List these targets
	@grep -hE '^[a-z][a-z-]*:.*## ' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  PORT=$(PORT) for serve and share."

all: font dict pages keylayout ## Build every artefact

site: dict pages ## Build everything servable into build/

font: $(FONT) ## Compile the font
dict: $(DICTIONARY) ## Build the searchable dictionary page
pages: $(STAMP) ## Rebuild docs/ into build/ with the font inlined
keylayout: $(KEYLAYOUT) ## Generate the macOS keyboard layout

$(FONT): $(UFO) tools/build_font.py
	$(PY) -m tools.build_font

$(DICTIONARY): $(WEB) $(LEXICON) tools/build_dictionary.py
	$(PY) -m tools.build_dictionary

$(STAMP): $(WEB) $(PAGES) tools/build_docs.py
	$(PY) -m tools.build_docs
	@touch $@

$(KEYLAYOUT): $(MODEL) $(SCRIPT) tools/build_keylayout.py
	$(PY) -m tools.build_keylayout

serve: site ## Serve build/ over HTTP
	$(PY) -m http.server -d build $(PORT)

share: site ## Serve build/ through a public cloudflared tunnel
	@command -v cloudflared >/dev/null 2>&1 || { \
	  echo "cloudflared is not on PATH."; \
	  echo "Either brew install cloudflared, or add pkgs.cloudflared to flake.nix."; \
	  exit 1; \
	}
	@echo "A quick tunnel is public: anyone with the URL can read build/ until this stops."
	@$(PY) -m http.server -d build $(PORT) >/dev/null 2>&1 & \
	  server=$$!; \
	  trap 'kill $$server 2>/dev/null' EXIT INT TERM; \
	  sleep 1; \
	  cloudflared tunnel --url http://localhost:$(PORT)

test: ## Run the test suite
	$(PY) -m pytest

typecheck: ## Type-check, strict
	$(PY) -m mypy

check: test typecheck ## Test and type-check

install: ## Build both halves and install them (macOS)
	./scripts/install.sh

clean: ## Delete build/
	rm -rf build
