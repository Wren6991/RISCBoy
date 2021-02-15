#!/usr/bin/env python3

# Mini tool for generating KiCad BGA footprints

pad_template = \
"""  (pad {name} smd circle (at {x} {y}) (size {diameter} {diameter}) (layers F.Cu F.Paste F.Mask)
    (solder_mask_margin {clearance}) (thermal_width {thermal_width}) (thermal_gap {thermal_gap}))
"""

line_template = \
"""  (fp_line (start {} {}) (end {} {}) (layer F.SilkS) (width 0.15))
"""

mod_template = \
"""(module {name} (layer F.Cu) (tedit 5A7E1D99)
  (fp_text reference REF** (at {ref_x} {ref_y}) (layer F.SilkS)
    (effects (font (size 1 1) (thickness 0.15)))
  )
  (fp_text value {name} (at {name_x} {name_y}) (layer F.Fab)
    (effects (font (size 1 1) (thickness 0.15)))
  )
{lines}
{pads}
)
"""


def pad(name, x, y, diameter, clearance=0.1, thermal_width=0.15, thermal_gap=0.15):
	return pad_template.format(name=name, x=x, y=y, diameter=diameter, clearance=clearance, thermal_width=thermal_width, thermal_gap=thermal_gap)


# Some BGAs look like this:
#
#    o o o o o o 
#    o o o o o o
#    o o     o o
#    o o     o o
#    o o o o o o
#    o o o o o o
#
# In this case, outer_count is 6 and inner_count is 2.

def number2letters(n):
	alphabet = "ABCDEFGHJKLMNPRTUVWY"
	if n:
		return number2letters((n - 1) // 20) + alphabet[(n - 1) % 20]
	else:
		return ""

def in_inner_square(i, j, outer_count, inner_count):
	start = (outer_count - inner_count) // 2
	r = range(start, start + inner_count)
	return i in r and j in r

def bga(pitch, pad_diam, pad_clearance, outer_count, inner_count=0):
	lines = []
	pads = []
	col_names = [str(i + 1) for i in range(outer_count)]
	row_names = [number2letters(int(x)) for x in col_names]
	grid_span = pitch * (outer_count - 1)
	corner = grid_span / 2 + pitch
	lines.append(line_template.format(-corner, -corner, -corner,  corner))
	lines.append(line_template.format(-corner,  corner,  corner,  corner))
	lines.append(line_template.format( corner,  corner,  corner, -corner))
	lines.append(line_template.format( corner, -corner, -corner, -corner))
	lines.append(line_template.format(-(corner + pitch * 1), -(corner + pitch * 1), -(corner + pitch * 1), -(corner + pitch * 2)))
	lines.append(line_template.format(-(corner + pitch * 1), -(corner + pitch * 2), -(corner + pitch * 2), -(corner + pitch * 1)))
	lines.append(line_template.format(-(corner + pitch * 2), -(corner + pitch * 1), -(corner + pitch * 1), -(corner + pitch * 1)))
	for i, col in enumerate(col_names):
		for j, row in enumerate(row_names):
			if in_inner_square(i, j, outer_count, inner_count):
				continue
			pads.append(pad(
				row + col,
				(i * pitch - grid_span / 2), (j * pitch - grid_span / 2),
				pad_diam, pad_clearance))
	return mod_template.format(
		name = "BGA_{}_{}mm".format(outer_count ** 2 - inner_count ** 2, pitch),
		ref_x = 0, ref_y = grid_span / 2 + 2,
		name_x = 0, name_y = -(grid_span / 2 + 2),
		lines = "".join(lines),
		pads = "".join(pads))