#include "addressmap.h"

.section .vectors

	li sp, SRAM1_BASE + SRAM1_SIZE
	jal _start

.halt:
	j .halt