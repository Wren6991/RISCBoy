#ifndef _ADDRESSMAP_H_
#define _ADDRESSMAP_H_

#define SRAM_BASE (0x2 << 28)
#define PERI_BASE (0x4 << 28)
#define GPIO_BASE (PERI_BASE + 0x0000)
#define UART_BASE (PERI_BASE + 0x1000)
#define TBMAN_BASE (PERI_BASE + 0xf000)

#define DECL_REG(addr, name) volatile uint32_t * const (name) = (volatile uint32_t*)(addr)

#endif // _ADDRESSMAP_H_