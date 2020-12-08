.define tilemap_loc 0x10000
.define tileset_loc 0x20000

	clip 0 319
loop:
	fill r=31
	atile 0 0 size=SIZE_16 pfsize=SIZE_128 \
		tilemap=tilemap_loc tileset=tileset_loc \
		fmt=FORMAT_ARGB1555 \
		a00=0x0080  a01=0x0080\
		a10=-0x0080 a11=0x0080
	sync
	push loop
	popj
