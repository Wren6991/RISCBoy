	.section .vectors

	// No vector table yet
	// stack @ 512k
	li sp, 0x20080000

	jal _start
.halt:
	j .halt