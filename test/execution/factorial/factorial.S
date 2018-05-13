_start:
	li sp, 0x400
	li a0, 5
	jal factorial
halt:
	j halt


factorial:
	beqz a0, fact_ret1
	addi sp, sp, -8
	sw t0, (sp)
	sw ra, 4(sp)
	mv t0, a0
	addi a0, a0, -1
	jal factorial
	mv a1, t0
	jal mul
	lw t0, (sp)
	lw ra, 4(sp)
	addi sp, sp, 8
	ret
fact_ret1:
	li a0, 1
	ret

mul:
	addi sp, sp, -8
	sw t0, (sp)
	sw t1, 4(sp)
	li t0, 0
	mv t1, a1
loop:
	beq t1, x0, mul_done
	add t0, t0, a0
	addi t1, t1, -1
	j loop
mul_done:
	mv a0, t0
	lw t0, (sp)
	lw t1, 4(sp)
	addi sp, sp, 8
	ret
