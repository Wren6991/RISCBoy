.define test_img_loc 0x20010000

	clip 0, 319

loop:
	fill 31, 0, 16

	blit 50, 100, size=SIZE_256, img=test_img_loc, fmt=FORMAT_ARGB1555

	ablit 0, 0, size=SIZE_256, img=test_img_loc, fmt=FORMAT_ARGB1555,\
		a00=0x000, a01=0x100,\
		a10=0x100, a11=0x000

	sync
	push loop
	popj

