#!/usr/bin/env python3

print("""
.define image_loc 0x10000
	clip 0 319
""")

for i in range(64): print(f"""
	fill 31 0 0
	blit {i-64}   0   size=SIZE_64 img=image_loc fmt=FORMAT_ARGB1555
	blit {320-i}   0   size=SIZE_64 img=image_loc fmt=FORMAT_ARGB1555
	sync""")

print("""
loop:
	fill 31 0 0
	sync
	push loop
	popj
""")
