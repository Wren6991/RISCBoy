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

localparam W_SPANTYPE     = 3;
localparam SPANTYPE_FILL  = 3'h0;
localparam SPANTYPE_BLIT  = 3'h2;
localparam SPANTYPE_TILE  = 3'h3;
localparam SPANTYPE_ABLIT = 3'h6;
localparam SPANTYPE_ATILE = 3'h7;

localparam INSTR_OPCODE_LSB = 28;
localparam INSTR_OPCODE_BITS = 4;

localparam OPCODE_SYNC  = 4'h0;
localparam OPCODE_CLIP  = 4'h1;
localparam OPCODE_FILL  = 4'h2;
localparam OPCODE_BLIT  = 4'h4;
localparam OPCODE_TILE  = 4'h5;
localparam OPCODE_ABLIT = 4'h6;
localparam OPCODE_ATILE = 4'h7;
localparam OPCODE_PUSH  = 4'he;
localparam OPCODE_POPJ  = 4'hf;

localparam INSTR_BCOND_BITS = 4;
localparam INSTR_BCOND_LSB = 24;
localparam BCOND_ALWAYS = 4'h0;
localparam BCOND_YLT = 4'h1;
localparam BCOND_YGE = 4'h2;

localparam INSTR_X_LSB = 0;
localparam INSTR_X_BITS = 10;
localparam INSTR_Y_LSB = 10;
localparam INSTR_Y_BITS = 10;

localparam INSTR_PALOFFS_LSB = 22;
localparam INSTR_PALOFFS_BITS = 3;
localparam INSTR_ABLIT_HALFSIZE_LSB = 21;
localparam INSTR_PIXMODE_LSB = 0;
localparam INSTR_PIXMODE_BITS = 2;

localparam INSTR_ADDR_MASK = 32'hffff_fffc;
localparam ADDR_BYTE_SHIFT = 1;

function [2:0] INSTR_BLIT_SIZE; input [31:0] instr; INSTR_BLIT_SIZE = instr[27:25]; endfunction
function [0:0] INSTR_TILE_SIZE; input [31:0] instr; INSTR_TILE_SIZE = instr[25]; endfunction
function [2:0] INSTR_PF_SIZE;   input [31:0] instr; INSTR_PF_SIZE = {1'b1, instr[1:0]}; endfunction
