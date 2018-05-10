
	li x8, 0
	li x9, 1
	li x11, 20
top:
	addi x11, x11, -1
	beq x11, x0, out
	add x10, x8, x9
	mv x8, x9
	mv x9, x10
	j top
out:
	j out