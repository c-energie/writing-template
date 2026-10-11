# Local builds. Overleaf ignores this file and runs its own toolchain, so keep the
# document buildable without it — anything essential belongs in main.tex or
# document_settings.sty, not here.
#
#   make            build the PDF
#   make clean      remove build intermediates, keep the PDF
#   make distclean  remove the PDF too
#   make test-setup test setup-nested.sh (POSIX sh, no network; not part of the build)

MAIN    = main
LATEXMK = latexmk -pdf -interaction=nonstopmode -halt-on-error

.PHONY: all clean distclean test-setup

all: $(MAIN).pdf

# latexmk decides how many passes biber and the glossary need.
$(MAIN).pdf: $(MAIN).tex
	$(LATEXMK) $(MAIN).tex

clean:
	latexmk -c
	rm -f *.acn *.acr *.alg *.glg *.glo *.gls *.ist *.bbl *.bcf *.run.xml

distclean: clean
	rm -f $(MAIN).pdf

# sh, not bash: the script promises POSIX sh, and on Linux sh is usually dash, which
# rejects the bashisms bash would let through.
test-setup:
	sh tests/setup-nested.test.sh
