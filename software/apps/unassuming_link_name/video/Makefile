.PHONY: raw quant

quantized: raw
	mkdir -p quant
	./mkframes.sh

raw:
	mkdir -p raw
	ffmpeg -i original_video.mp4 -filter:v "crop=1380:1080:270:0" -r 29.3 -s 128x128 -aspect 1:1 raw/frame%04d.bmp
	echo $(RAW_FRAMES)

clean:
	rm -rf raw quantized
