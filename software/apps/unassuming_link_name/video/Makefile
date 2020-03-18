.PHONY: raw quant pack

pack: quant
	mkdir -p pack
	./mkpack.sh

quant: raw
	mkdir -p quant
	./mkframes.sh

raw:
	mkdir -p raw
	ffmpeg -i original_video.mp4 -filter:v "crop=1380:1080:270:0" -s 128x128 -aspect 1:1 raw/frame%04d.bmp

clean:
	rm -rf raw quant pack
