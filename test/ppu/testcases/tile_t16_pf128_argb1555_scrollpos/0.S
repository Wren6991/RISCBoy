.define tilemap_loc 0x10000
.define tileset_loc 0x20000

	clip 0 319
loop:
	fill r=31
	tile 25 13 size=SIZE_16 pfsize=SIZE_128 \
		tilemap=tilemap_loc tileset=tileset_loc \
		fmt=FORMAT_ARGB1555
	sync
	push loop
	popj
