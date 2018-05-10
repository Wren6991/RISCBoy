	// Give each of the branch conditions a quick spin to check they are
	// more-or-less working

	li x1, 1
	li x2, -1

	beq x1, x2, l0
	li x16, 1
	j l1
l0:
	li x16, 2
l1:

	bne x1, x2, l2
	li x17, 1
	j l3
l2:
	li x17, 2
l3:

	blt x1, x2, l4
	li x18, 1
	j l5
l4:
	li x18, 2
l5:

	bge x1, x2, l6
	li x19, 1
	j l7
l6:
	li x19, 2
l7:

	bltu x1, x2, l8
	li x20, 1
	j l9
l8:
	li x20, 2
l9:

	bgeu x1, x2, l10
	li x21, 1
	j l11
l10:
	li x21, 2
l11:

halt:
	j halt