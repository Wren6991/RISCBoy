localparam W_PIXMODE = 3;
localparam PIXMODE_ARGB1555 = 3'h0;
localparam PIXMODE_ARGB1232 = 3'h2;
localparam PIXMODE_PAL8     = 3'h4;
localparam PIXMODE_PAL4     = 3'h5;
localparam PIXMODE_PAL2     = 3'h6;
localparam PIXMODE_PAL1     = 3'h7;

function       MODE_IS_PALETTED; input [2:0] pixmode; MODE_IS_PALETTED = pixmode[2]; endfunction
function [2:0] MODE_LOG_PIXSIZE; input [2:0] pixmode; MODE_LOG_PIXSIZE = MODE_IS_PALETTED(pixmode) ? 3'h7 - pixmode : 3'h4 >> pixmode[1]; endfunction

localparam W_TILENUM = 8; // always 8 bits per tile!

localparam W_TILE_MAX = 16;
localparam LOG_W_TILE_MAX = 4;
