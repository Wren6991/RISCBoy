// Stein's GCD algorithm

	li x8, 7890
	li x9, 123456
	li x10, 0
loop:
	beq x8, x0, out
	andi x11, x8, 1
	beq x11, x0, a_even
a_odd:
	andi x11, x9, 1
	beq x11, x0, a_odd_b_even
a_odd_b_odd:
	blt x9, x8, noswap
	mv x11, x8
	mv x8, x9
	mv x9, x11
noswap:
	sub x8, x8, x9
	srli x8, x8, 1
	j loop
a_odd_b_even:
	srli x9, x9, 1
	bge x9, x8, noswap_2
	mv x11, x8
	mv x8, x9
	mv x9, x11
noswap_2:
	j loop
a_even:
	andi x11, x9, 1
	beq x11, x0, a_even_b_even
a_even_b_odd:
	srli x8, x8, 1
	j loop
a_even_b_even:
	srli x8, x8, 1
	srli x9, x9, 1
	addi x10, x10, 1
	j loop
out:
	sll  x9, x9, x10

halt:
	j halt
