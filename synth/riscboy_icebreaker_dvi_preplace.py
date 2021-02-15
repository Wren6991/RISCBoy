import re

print("\n>>>>> Preplace start\n")

ctx.addClock("clk_bit", 126)
ctx.addClock("clk_pix", 25.2)
ctx.addClock("clk_sys", 14)

def floorplan(region, cell_match, exclude = set()):
	print(f"\n>>> Floorplanning cells matching '{cell_match}' to {region}")
	floorplanned = []
	for cellname, _ in ctx.cells:
		if cellname not in exclude and cell_match in cellname:
			print(f"Floorplanning {cellname} to {region}")
			ctx.constrainCellToRegion(cellname, region)
			floorplanned.append(cellname)
	return set(floorplanned)


ctx.createRectangularRegion("dvi_ser",7, 26, 18, 31)
ctx.createRectangularRegion("dvi_pixfifo", 6, 24, 16, 26)
ctx.createRectangularRegion("dvi_misc", 0, 22, 10, 31)

dvi_exclude = set()
dvi_exclude |= floorplan("dvi_ser", "dispctrl_dvi_u.ser", exclude=dvi_exclude)
dvi_exclude |= floorplan("dvi_pixfifo", "dispctrl_dvi_u.pixel_fifo", exclude=dvi_exclude)
dvi_exclude |= floorplan("dvi_pixfifo", "dispctrl_dvi_u.pxfifo", exclude=dvi_exclude)

# Try to keep processor register file and the processor-only memory (SRAM1)
# toward the bottom side of the chip, away from the DIV bits.
# 16 for sram1 + 4 for regfile. 2 columns, each BRAM 2 tiles high. Plus one extra pair for breathing room.
ctx.createRectangularRegion("cpu_mem", 0, 1, 25, 24)
floorplan("cpu_mem", "sram1.sram.behav_mem.mem")
floorplan("cpu_mem", "inst_regfile_1w2r.real_dualport_noreset.mem")

print("\n>>>>> Preplace done\n")
