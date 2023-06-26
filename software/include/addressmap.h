#ifndef _ADDRESSMAP_H_
#define _ADDRESSMAP_H_

// External SRAM/main memory:
#define SRAM0_BASE (0x00u << 16)
#define SRAM0_SIZE (512 * 1024)

// Boot/stack SRAM, 512 kiB above base of SRAM0:
#define SRAM1_BASE (0x08u << 16)
#define SRAM1_SIZE (8 * 1024)

// Peripherals 256 kiB above base of SRAM1:
#define PERI_BASE  (0x0cu << 16)
#define GPIO_BASE  (PERI_BASE + 0x0000)
#define UART_BASE  (PERI_BASE + 0x1000)
#define PWM_BASE   (PERI_BASE + 0x2000)
#define SPI_BASE   (PERI_BASE + 0x3000)
#define PPU_BASE   (PERI_BASE + 0x4000)
#define DISP_BASE  (PERI_BASE + 0x5000)
#define TBMAN_BASE (PERI_BASE + 0xf000)


#ifndef __ASSEMBLER__

#include <stdint.h>

#define DECL_REG(addr, name) volatile uint32_t * const (name) = (volatile uint32_t*)(addr)

#define __time_critical __attribute__((section(".time_critical")))

typedef volatile uint32_t io_rw_32;

#endif

#endif // _ADDRESSMAP_H_
