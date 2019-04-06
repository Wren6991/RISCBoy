LATEX=pdflatex
LATEXARGS=-halt-on-error
DOCNAME=riscboy_doc
PDFVIEWER=evince

all: $(DOCNAME).pdf

$(DOCNAME).pdf: $(wildcard *.tex)
	make -C waves
	$(LATEX) $(LATEXARGS) $(DOCNAME).tex
	$(LATEX) $(LATEXARGS) $(DOCNAME).tex

clean:
	rm -f $(DOCNAME).log *.aux $(DOCNAME).toc $(DOCNAME).lof $(DOCNAME).sync.gz $(DOCNAME).pdf $(DOCNAME).out
	make -C waves clean

view: $(DOCNAME).pdf
	$(PDFVIEWER) $(DOCNAME).pdf

