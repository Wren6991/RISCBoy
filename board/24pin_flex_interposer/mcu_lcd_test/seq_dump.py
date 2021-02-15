#!/usr/bin/env python3

import sys

files = [
	"dump_db15:12.csv",
	"dump_db11:8.csv",
	"dump_db7:4.csv",
	"dump_db3:0.csv"
]

def loadcsv(fname):
	first = True
	data = []
	for l in open(fname):
		if first:
			first = False
			continue
		data.append(int(l.split(",")[-1], 0))
	return data

def print_with_repeats(l, data_mask=0xf):
	rs_mask = (data_mask << 1) & -data_mask
	l = iter(l)
	item = next(l, None)
	while item is not None:
		print(f"{'DAT' if item & rs_mask else 'CMD'}: {item & data_mask:x}")
		first_of_run = item
		item = next(l, None)
		count = 1
		while item is not None and item == first_of_run:
			count += 1
			item = next(l, None)
		if count > 1:
			print(f"(repeated {count} times)")


# print_with_repeats(loadcsv(sys.argv[1]))

datastreams = []
for f in files:
	datastreams.append(loadcsv(f))

stream_len = min(len(d) for d in datastreams)

for i, v in enumerate(datastreams):
	datastreams[i] = v[0:stream_len]

# Check that CMD and DAT register select always matches up
for i in range(stream_len):
	for j in range(1, len(datastreams)):
		assert((datastreams[j][i] & 0x10) == (datastreams[0][i] & 0x10))

output = list(datastreams[0][i] << 12 | (datastreams[1][i] & 0xf) << 8 | (datastreams[2][i] & 0xf) << 4 | (datastreams[3][i] & 0xf) for i in range(stream_len))
print_with_repeats(output, data_mask=0xffff)
