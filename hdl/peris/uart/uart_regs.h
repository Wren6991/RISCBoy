/*******************************************************************************
*                          AUTOGENERATED BY REGBLOCK                           *
*                            Do not edit manually.                             *
*          Edit the source file (or regblock utility) and regenerate.          *
*******************************************************************************/

#ifndef _UART_REGS_H_
#define _UART_REGS_H_

// Block name           : uart
// Bus type             : apb
// Bus data width       : 32
// Bus address width    : 16

#define UART_CSR_OFFS 0
#define UART_DIV_OFFS 4
#define UART_FSTAT_OFFS 8
#define UART_TX_OFFS 12
#define UART_RX_OFFS 16

/*******************************************************************************
*                                     CSR                                      *
*******************************************************************************/

// Control and status register

// Field CSR_EN
// UART runs when en is high. Synchronous reset (excluding FIFOs) when low.
#define UART_CSR_EN_LSB  0
#define UART_CSR_EN_BITS 1
#define UART_CSR_EN_MASK 0x1
// Field CSR_BUSY
// UART TX is still sending data
#define UART_CSR_BUSY_LSB  1
#define UART_CSR_BUSY_BITS 1
#define UART_CSR_BUSY_MASK 0x2
// Field CSR_TXIE
// Enable TX FIFO interrupt
#define UART_CSR_TXIE_LSB  2
#define UART_CSR_TXIE_BITS 1
#define UART_CSR_TXIE_MASK 0x4
// Field CSR_RXIE
// Enable RX FIFO interrupt
#define UART_CSR_RXIE_LSB  3
#define UART_CSR_RXIE_BITS 1
#define UART_CSR_RXIE_MASK 0x8

/*******************************************************************************
*                                     DIV                                      *
*******************************************************************************/

// Clock divider control fields

// Field DIV_INT
#define UART_DIV_INT_LSB  8
#define UART_DIV_INT_BITS 10
#define UART_DIV_INT_MASK 0x3ff00
// Field DIV_FRAC
#define UART_DIV_FRAC_LSB  0
#define UART_DIV_FRAC_BITS 8
#define UART_DIV_FRAC_MASK 0xff

/*******************************************************************************
*                                    FSTAT                                     *
*******************************************************************************/

// FIFO status register

// Field FSTAT_TXLEVEL
#define UART_FSTAT_TXLEVEL_LSB  0
#define UART_FSTAT_TXLEVEL_BITS 2
#define UART_FSTAT_TXLEVEL_MASK 0x3
// Field FSTAT_TXFULL
#define UART_FSTAT_TXFULL_LSB  8
#define UART_FSTAT_TXFULL_BITS 1
#define UART_FSTAT_TXFULL_MASK 0x100
// Field FSTAT_TXEMPTY
#define UART_FSTAT_TXEMPTY_LSB  9
#define UART_FSTAT_TXEMPTY_BITS 1
#define UART_FSTAT_TXEMPTY_MASK 0x200
// Field FSTAT_RXLEVEL
#define UART_FSTAT_RXLEVEL_LSB  16
#define UART_FSTAT_RXLEVEL_BITS 2
#define UART_FSTAT_RXLEVEL_MASK 0x30000
// Field FSTAT_RXFULL
#define UART_FSTAT_RXFULL_LSB  24
#define UART_FSTAT_RXFULL_BITS 1
#define UART_FSTAT_RXFULL_MASK 0x1000000
// Field FSTAT_RXEMPTY
#define UART_FSTAT_RXEMPTY_LSB  25
#define UART_FSTAT_RXEMPTY_BITS 1
#define UART_FSTAT_RXEMPTY_MASK 0x2000000

/*******************************************************************************
*                                      TX                                      *
*******************************************************************************/

// TX data FIFO

// Field TX
#define UART_TX_LSB  0
#define UART_TX_BITS 8
#define UART_TX_MASK 0xff

/*******************************************************************************
*                                      RX                                      *
*******************************************************************************/

// RX data FIFO

// Field RX
#define UART_RX_LSB  0
#define UART_RX_BITS 8
#define UART_RX_MASK 0xff

#endif // _UART_REGS_H_