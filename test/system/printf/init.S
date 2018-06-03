	.section .vectors

	// No vector table yet
	// stack @ 0.5M (top of RAM)
	li sp, 0x20080000

	jal _start
.halt:
	j .halt