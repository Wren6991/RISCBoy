#!/bin/bash

for frame in $(find raw -name "*.bmp" | sort)
do
	echo ${frame}
	qframe=${frame/raw/quant}
	# Yes this is garbage and I am garbage, but PIL only supports dithering to the web palette (?????) and will not dither when using an adaptive palette
	gimp -ib "(let* ((image (car (gimp-file-load 1 \"$frame\" \"$frame\")) )) (gimp-image-convert-indexed image CONVERT-DITHER-FS CONVERT-PALETTE-GENERATE 16 FALSE FALSE \"I can put what I like here!\")  (gimp-file-save 1 image (car (gimp-image-get-active-layer image)) \"$qframe\" \"$qframe\") ) (gimp-quit 0)"
done
