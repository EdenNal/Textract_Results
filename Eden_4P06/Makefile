MS = $(shell basename `pwd`)

## allow colour changes in echo commands
## these must be exported so they are visible inside all rules,
## then used via $$.
export RED  := $(shell tput setaf 1)
export BLUE := $(shell tput setaf 4)
export BOLD := $(shell tput bold)
export NC   := $(shell tput sgr0)  # no colour, no style

## Prevent make from auto-deleting intermediate %.pdf/%.tex when building %.open
.PRECIOUS: %.pdf %.tex

## ------------------------------------------------------------
## Build rules
## ------------------------------------------------------------

## Open the PDF (macOS)
%.open: %.pdf
	open "$<"

## Rnw -> tex (knitr)
## Use $(wildcard ...) so missing/empty dirs don't cause "No rule to make target ...".
%.tex: %.Rnw $(wildcard flowcharts/*.pdf) $(wildcard figs/*) $(wildcard preamble*)
	@echo
	@echo $${BLUE}${MS}$${NC}
	@echo
	@echo $${BOLD}$${RED}Rnw to tex ...$${NC}
	Rscript -e "library(knitr); knit('$*.Rnw')"

## tex -> pdf (latexmk)
LATEXMK      := latexmk
LATEXMKFLAGS := -pdf -silent -use-make

%.pdf: %.tex FORCE
	@echo $${BOLD}$${RED}tex to pdf ...$${NC}
	$(LATEXMK) $(LATEXMKFLAGS) "$*"
	@echo $${BOLD}$${BLUE}`date`$${NC}

## ------------------------------------------------------------
## Cleaning (stem-specific, cautious)
##
## Examples:
##   make epimom.clean
##   make epimom.fresh
##   make fresh            # same as: make $(MS).fresh
##
## No target ever deletes all PDFs in the directory.
## ------------------------------------------------------------

.PHONY: clean veryclean superclean fresh FORCE
FORCE:
	@:

## Default wrappers act on $(MS)
clean:      $(MS).clean
veryclean:  $(MS).veryclean
superclean: $(MS).superclean
fresh:      $(MS).fresh

## Level 1: common LaTeX aux files
%.clean: FORCE
	@rm -f "$*.aux" "$*.tikz" "$*.out" "$*.log" "$*.blg" "$*.toc"

## Level 2: latexmk / beamer / tikz extras (still no PDFs)
%.veryclean: %.clean FORCE
	@rm -f "$*.nav" "$*.snm" "$*.fls" "$*.fdb_latexmk" "$*-tikzDictionary" "$*.synctex.gz"

## Level 3: bibliography output (still no PDFs)
%.superclean: %.veryclean FORCE
	@rm -f "$*.bbl"

## Level 4: “fresh build”
## - removes only this stem’s PDF
## - removes this stem’s .tex only if $*.Rnw exists (i.e., .tex is generated)
%.fresh: %.superclean FORCE
	@rm -f "$*.pdf"
	@if [ -f "$*.Rnw" ]; then rm -f "$*.tex"; fi
