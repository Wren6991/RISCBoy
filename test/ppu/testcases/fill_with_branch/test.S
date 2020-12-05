	clip 0, 319

loop1:
	fill 31, 0, 0
	sync
	push loop1
	popj ylt 79

loop2:
	fill 0, 31, 0
	sync
	push loop3
	popj yge 159
	push loop2
	popj

loop3:
	fill 0, 0, 31
	sync
	push loop3
	popj
