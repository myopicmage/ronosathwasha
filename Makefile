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
LEVEL ?= sentence
CHECK_JOBS ?= 3

# Empty under direnv, which is the usual case: the toolchain is already on
# PATH. Outside it, every recipe re-enters the dev shell, the way
# scripts/install.sh does. `path:.` copies the working tree into the store on
# each evaluation, so avoid writing into it from elsewhere while this runs.
# Probes one tool per half of the toolchain. Checking only fontmake was enough
# until Raku arrived, and then a direnv shell cached from before that change
# passed the test while missing half of what the recipes call.
RESHELL := $(shell { command -v fontmake && command -v raku; } >/dev/null 2>&1 || echo "nix develop 'path:.' --command")
PY := $(RESHELL) python3

# Raku addresses module repositories by a spec rather than a path, and zef
# cannot write to rakudo's own repository because it lives in the read-only nix
# store. So the distribution's dependencies go into a project-local one and
# every Raku command names it.
#
# The `\#` is not decoration, and the spec is built here exactly once because
# the escape does not behave the same way in both places. An unescaped `#`
# opens a comment even inside a quoted assignment, truncating this to `inst`.
# Escaping it in an assignment yields a literal `#`, but escaping it in a
# recipe leaves the backslash in place for the shell, and zef reads `inst\` as
# an unknown repository type.
RAKU_DEPS := .raku
RAKU_REPO := inst\#$(RAKU_DEPS)
RAKU_STAMP := $(RAKU_DEPS)/.deps.stamp
RAKU := $(RESHELL) env RAKULIB="$(RAKU_REPO)"

MODEL := $(wildcard ronosathwasha/*.py)
SCRIPT := data/script.toml
LEXICON := data/lexicon.toml
MORPHOLOGY := data/morphology.toml

# The declaration plus everything that turns it into outlines. Any of these
# moving changes the shapes, so anything carrying a font is out of date.
UFO := $(MODEL) $(SCRIPT) sources/strokes.py tools/build_ufo.py
WEB := $(UFO) tools/webfont.py

FONT := build/Ronosathwasha.ttf
DICTIONARY := build/dictionary.html
SYLLABARY := build/syllabary.html
KEYLAYOUT := layouts/Ronosathwasha.keylayout
PAGES := $(wildcard docs/*.html)

# build_docs writes one file per page from a single run. A stamp is how make
# expresses "these outputs, one command", without claiming each page is built
# independently.
STAMP := build/.docs.stamp

.DEFAULT_GOAL := help

.PHONY: help all site font dict syllabary pages keylayout serve share speak validate chat chat-all test raku-test typecheck check install clean

help: ## List these targets
	@grep -hE '^[a-z][a-z-]*:.*## ' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  PORT=$(PORT) for serve and share."

all: font dict pages keylayout ## Build every artefact

site: dict syllabary pages ## Build everything servable into build/

font: $(FONT) ## Compile the font
dict: $(DICTIONARY) ## Build the searchable dictionary page
syllabary: $(SYLLABARY) ## Build the specimen sheet of every syllable
pages: $(STAMP) ## Rebuild docs/ into build/ with the font inlined
keylayout: $(KEYLAYOUT) ## Generate the macOS keyboard layout

$(FONT): $(UFO) tools/build_font.py
	$(PY) -m tools.build_font

# The conjugation tables. Raku chooses the alternants, because that is
# morphology; Python renders them, because that is typography and the page it
# goes on already carries the font. A computed result, not a second copy of a
# declaration: delete it and the next build makes the same file.
PARADIGMS := build/paradigms.toml

$(PARADIGMS): $(RAKU_STAMP) $(MORPHOLOGY) $(LEXICON) $(SCRIPT) tools/paradigms.raku
	$(RAKU) raku -I lib tools/paradigms.raku

$(DICTIONARY): $(WEB) $(LEXICON) $(PARADIGMS) tools/build_dictionary.py
	$(PY) -m tools.build_dictionary

# The specimen sheet. Depends on nothing but the shapes: it shows the syllabary
# rather than the vocabulary, so the lexicon moving does not date it.
$(SYLLABARY): $(WEB) tools/build_syllabary.py
	$(PY) -m tools.build_syllabary

$(STAMP): $(WEB) $(PAGES) tools/build_docs.py
	$(PY) -m tools.build_docs
	@touch $@

$(KEYLAYOUT): $(MODEL) $(SCRIPT) tools/build_keylayout.py
	$(PY) -m tools.build_keylayout

# The language, heard. Not part of `all`, because it writes audio nobody is
# waiting on and the questions it answers are asked rarely.
speak: ## Speak the language into build/speech
	$(PY) -m tools.speak --demo

validate: $(RAKU_STAMP) ## Validate Rono in TEXT at writing, word, or sentence LEVEL
	@test -n "$(TEXT)" || { echo "usage: make validate TEXT='Lari thinəme.' [LEVEL=sentence]"; exit 2; }
	$(RAKU) raku -I lib tools/validate.raku --level="$(LEVEL)" "$(TEXT)"

chat: $(RAKU_STAMP) ## Start the local Lauri conversation
	$(RAKU) bin/ronosathwasha-chat

chat-all: $(RAKU_STAMP) ## Start llama-server and the local Lauri conversation
	./scripts/chat-all.sh

serve: site ## Serve build/ over HTTP
	$(PY) -m http.server -d build $(PORT)

share: site ## Serve build/ through a public cloudflared tunnel
	./scripts/share.sh $(PORT)

test: ## Run the test suite
	$(PY) -m pytest

# zef exits nonzero when every dependency is already installed, reporting the
# skips as failures, so this recipe cannot gate on its status. It distinguishes
# the two cases by result instead: a repository directory exists either way
# after a real install, and does not exist at all after a genuine failure on a
# clean tree.
#
# The stamp is what make tracks, not the directory. A directory's timestamp
# moves whenever anything inside it does, so declaring the target against
# `.raku` itself would reinstall on the next run after any zef activity.
$(RAKU_STAMP): META6.json
	-$(RESHELL) zef install --to="$(RAKU_REPO)" --deps-only .
	@test -d $(RAKU_DEPS) || { echo "zef could not create $(RAKU_DEPS)"; exit 1; }
	@touch $@

raku-test: $(RAKU_STAMP) ## Run the Raku test suite
	$(RAKU) zef test .

typecheck: ## Type-check, strict
	$(PY) -m mypy

check: $(RAKU_STAMP) ## Test and type-check
	+$(MAKE) -j$(CHECK_JOBS) test raku-test typecheck

install: ## Build both halves and install them (macOS)
	./scripts/install.sh

clean: ## Delete build/
	rm -rf build
