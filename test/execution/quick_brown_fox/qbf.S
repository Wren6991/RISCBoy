// Use every opcode once (part of the "kick the tyres" testing initiative)

// load/stores, branches each have a dedicated testcase. 

// Shifts

	li x30, 0x80008000
	li x31, 2

	sll x1, x30, x31
	slli x2, x30, 3
	srl x3, x30, x31
	srli x4, x30, 3
	sra x5, x30, x31
	srai x6, x30, 3

// Arithmetic

	li x30, 0x1234
	li x31, 0x5678

	add x7, x30, x31
	addi x8, x30, 0x7cd
	sub x9, x30, x31
	lui x10, 0x20008
	auipc x11, 0x10000

// Logical

	li x30, 0x1234
	li x31, 0x5678

	xor x12, x30, x31
	xori x13, x30, -1
	or x14, x30, x31
	ori x15, x30, -1
	and x16, x30, x31
	andi x17, x30, 0xff

// Comparison

	li x30, 0x7fffffff
	li x31, 0x80000000

	slt x18, x30, x31
	slti x19, x31, 0
	sltu x20, x30, x31
	sltiu x21, x31, 0

halt:
	j halt