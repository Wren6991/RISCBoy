APPNAME=sprite_demo
SRC_DIR=$(SOFTWARE)/src
SRCS=$(SRC_DIR)/init.S $(SRC_DIR)/$(APPNAME).c

include ../flash_app.mk

.PHONY: assets
assets:
	$(SCRIPTS)/packtiles -t 16 -f p8 zelda_mini_plus_walk.png tileset.bin
	xxd -i tileset.bin > tileset.h
	xxd -i tileset.bin.pal > tileset_pal.h
