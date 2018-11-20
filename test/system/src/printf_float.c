#include "tbman.h"

int main()
{
	volatile float x = 3142.f;
	volatile float y = 1000.f;
	tbman_putint((int)x);
	tbman_putint((int)y);
	volatile float z = x / y;
	tbman_putint((int)z);

	tbman_printf("%f", z);

	tbman_exit(0);
}