
	li x1, 1000
	li x2, 0x1234
	li x3, 0x5678
	li x4, 0x9abc
	li x5, 0xdef0

	sw x2, (x1)
	lw x8, (x1)
	sh x3, 2(x1)
	lw x9, (x1)
	sh x4, (x1)
	lb x10, 1(x1)
	lbu x11, 1(x1)
	sb x5, 2(x1)
	sb x2, 3(x1)
	lw x12, (x1)
	lh x13, (x1)
	lhu x14, (x1)


halt:
	j halt

.word 0, 0
