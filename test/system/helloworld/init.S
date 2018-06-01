	.section .vectors

	// No vector table yet
	// stack @ 32k
	li sp, 0x20008000

	jal _start
.halt:
	j .halt