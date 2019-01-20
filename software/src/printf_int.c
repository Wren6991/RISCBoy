#include "tbman.h"

int main()
{
	tbman_puts("Starting\n");
	tbman_printf("String printf\n");
	tbman_printf("Printing int: %d\n", 1234);
	tbman_exit(0);
}