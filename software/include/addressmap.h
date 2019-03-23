#ifndef _ADDRESSMAP_H_
#define _ADDRESSMAP_H_

// External SRAM/main memory:
#define SRAM0_BASE (0x2ul << 28)
#define SRAM0_SIZE (512 * 1024)

// Boot/stack SRAM:
#define SRAM1_BASE (SRAM0_BASE + SRAM0_SIZE)
#define SRAM1_SIZE (8 * 1024)

#define PERI_BASE  (0x4ul << 28)
#define GPIO_BASE  (PERI_BASE + 0x0000)
#define UART_BASE  (PERI_BASE + 0x1000)
#define PWM_BASE   (PERI_BASE + 0x2000)
#define TBMAN_BASE (PERI_BASE + 0xf000)

#define DECL_REG(addr, name) volatile uint32_t * const (name) = (volatile uint32_t*)(addr)

#endif // _ADDRESSMAP_H_