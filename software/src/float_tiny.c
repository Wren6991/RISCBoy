#include "tbman.h"

int main()
{
	// volatile to avoid constant folding
	volatile float a = 2.25f;
	volatile float b = 12.f;
	volatile float c = a * b / 1.3f;
	tbman_exit((uint32_t)c);
}