.PHONY: frames
frames:
	mkdir -p frames
	ffmpeg -i original_video.mp4 -filter:v "crop=1380:1080:270:0" -r 29.3 -s 128x128 -aspect 1:1 frames/frame%04d.bmp

