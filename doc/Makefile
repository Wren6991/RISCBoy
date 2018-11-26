DOCNAME=riscboy_doc
PDFVIEWER=evince

all: $(DOCNAME).pdf

$(DOCNAME).pdf: $(DOCNAME).tex
	make -C waves
	pdflatex $(DOCNAME).tex
	pdflatex $(DOCNAME).tex

clean:
	rm -f $(DOCNAME).log $(DOCNAME).aux $(DOCNAME).toc $(DOCNAME).sync.gz $(DOCNAME).pdf $(DOCNAME).out
	make -C waves clean

view: $(DOCNAME).pdf
	$(PDFVIEWER) $(DOCNAME).pdf

