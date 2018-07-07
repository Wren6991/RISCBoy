SRCS=$(wildcard *.svg)
TARGETS=$(patsubst %.svg,%.pdf,$(SRCS))
# rsvg-convert can be obtained on Ubuntu by entering:
# sudo apt install librsvg2-dev
CONVERT=rsvg-convert -f pdf

.PHONY: all clean

all: $(TARGETS)

%.pdf: %.svg
	$(CONVERT) $< -o $@

clean:
	rm -f $(TARGETS)