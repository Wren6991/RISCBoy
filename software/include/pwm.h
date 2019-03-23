#ifndef _PWM_H_
#define _PWM_H_

#include <stdbool.h>
#include <stdint.h>

#include "addressmap.h"
#include "hw/pwm_tiny_regs.h"

DECL_REG(PWM_BASE + PWM_TINY_CTRL_OFFS, PWM_CTRL);

static inline void pwm_enable(bool en)
{
	*PWM_CTRL = *PWM_CTRL & ~PWM_TINY_CTRL_EN_MASK | (!!(unsigned)en << PWM_TINY_CTRL_EN_LSB);
}

static inline void pwm_invert(bool inv)
{
	*PWM_CTRL = *PWM_CTRL & ~PWM_TINY_CTRL_INV_MASK | (!!(unsigned)inv << PWM_TINY_CTRL_INV_LSB);
}

static inline void pwm_div(uint8_t div)
{
	*PWM_CTRL = *PWM_CTRL & ~PWM_TINY_CTRL_DIV_MASK | (div << PWM_TINY_CTRL_DIV_LSB);
}

static inline void pwm_val(uint8_t val)
{
	*PWM_CTRL = *PWM_CTRL & ~PWM_TINY_CTRL_VAL_MASK | (val << PWM_TINY_CTRL_VAL_LSB);
}

#endif // _PWM_H_