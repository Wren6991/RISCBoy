DOCNAME=fpgaboy_doc
PDFVIEWER=evince

all: $(DOCNAME).pdf

$(DOCNAME).pdf: $(DOCNAME).tex
	pdflatex $(DOCNAME).tex
	pdflatex $(DOCNAME).tex

clean:
	rm -f $(DOCNAME).log $(DOCNAME).aux $(DOCNAME).toc $(DOCNAME).sync.gz $(DOCNAME).pdf

view: $(DOCNAME).pdf
	$(PDFVIEWER) $(DOCNAME).pdf

