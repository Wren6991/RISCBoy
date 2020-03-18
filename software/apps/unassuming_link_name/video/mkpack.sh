#!/bin/bash

for frame in $(find quant -name "*.bmp" | sort)
do
	echo ${frame}
	pframe=${frame/quant/pack}
	pframe=${pframe/.bmp/.bin}
	packtiles -f p4 -t 128 ${frame} ${pframe}
	cat ${pframe} >> ${pframe}.pal
	mv ${pframe}.pal ${pframe}
done
