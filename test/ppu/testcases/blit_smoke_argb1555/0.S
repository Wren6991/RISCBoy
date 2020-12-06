.define image_loc 0x10000

	clip 0 319
loop:
	fill 31 0 0
	blit 0   0   size=SIZE_64 img=image_loc fmt=FORMAT_ARGB1555
	blit 256 0   size=SIZE_64 img=image_loc fmt=FORMAT_ARGB1555
	blit 0   176 size=SIZE_64 img=image_loc fmt=FORMAT_ARGB1555
	blit 256 176 size=SIZE_64 img=image_loc fmt=FORMAT_ARGB1555
	sync
	push loop
	popj
