#include "tbman.h"

int gcd(int x, int y)
{
	if (y == 0)
		return x;
	else
		return gcd(y, x % y);
}

struct {int x; int y;} tests[] = {
	{5, 4},
	{6, 3},
	{120, 5},
	{120, 20},
	{12345, 678}
};

int main()
{
	for (int i = 0; i < sizeof(tests) / sizeof(*tests); ++i)
		tbman_putint(gcd(tests[i].x, tests[i].y));
	tbman_exit(0);
}