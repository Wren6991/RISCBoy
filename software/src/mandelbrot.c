#include <stdint.h>
#include <stdbool.h>

#include "tbman.h"

#define WIDTH 80
#define HEIGHT 60

#define SCALE 16
#define ITERS 100
#define ESCAPE (1000 << SCALE)

int main()
{
	for (int y = 0; y < HEIGHT; ++y)
	{
		for (int x = 0; x < WIDTH; ++x)
		{
			int32_t cr = (x - WIDTH / 2 - 10) << (SCALE - 5);
			int32_t ci = (y - HEIGHT / 2) << (SCALE - 5);
			int32_t zr = cr;
			int32_t zi = ci;
			bool escaped = false;
			for (int i = 0; i < ITERS; ++i)
			{
				int32_t zr_tmp = ((((int64_t)zr * zr) - ((int64_t)zi * zi)) >> SCALE) + cr;
				zi = 2 * (((int64_t)zr * zi) >> SCALE) + ci;
				zr = zr_tmp;
				if (zi < -ESCAPE || zi > ESCAPE || zr < -ESCAPE || zr > ESCAPE)
				{
					escaped = true;
					break;
				}
			}
			tbman_putc(escaped ? ' ' : '#');
		}
		tbman_putc('\n');
	}

	tbman_exit(0);
}