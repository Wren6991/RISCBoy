localparam W_PIXMODE = 2;
localparam PIXMODE_ARGB1555 = 2'h0;
localparam PIXMODE_PAL8     = 2'h1;
localparam PIXMODE_PAL4     = 2'h2;
localparam PIXMODE_PAL1     = 2'h3;

function MODE_IS_PALETTED;
	input [1:0] pixmode;
	MODE_IS_PALETTED = |pixmode;
endfunction

function [2:0] MODE_LOG_PIXSIZE;
	input [1:0] pixmode;
	MODE_LOG_PIXSIZE = &pixmode? 0 : 3'h4 - pixmode;
endfunction

localparam W_TILENUM = 8; // always 8 bits per tile!

localparam W_TILE_MAX = 16;
localparam LOG_W_TILE_MAX = 4;
