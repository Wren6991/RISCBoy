/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2019 Luke Wren                                       *
 *                                                                    *
 * Everyone is permitted to copy and distribute verbatim or modified  *
 * copies of this license document and accompanying software, and     *
 * changing either is allowed.                                        *
 *                                                                    *
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION  *
 *                                                                    *
 * 0. You just DO WHAT THE FUCK YOU WANT TO.                          *
 * 1. We're NOT RESPONSIBLE WHEN IT DOESN'T FUCKING WORK.             *
 *                                                                    *
 *********************************************************************/

// Logic for streaming in bus data, seeking to output-size-aligned offset
// if just flushed, and streaming data out at some width.

module riscboy_ppu_pixel_streamer #(
	parameter W_DATA = 32,
	parameter W_PIX_MAX = 16,
	// Driven parameters:
	parameter W_SHIFTCTR = $clog2(W_DATA),
	parameter W_SHAMT = $clog2(W_SHIFTCTR + 1)
) (
	input  wire                  clk,
	input  wire                  rst_n,


	input  wire                  flush,
	input  wire                  flush_unaligned,
	input  wire [W_SHIFTCTR-1:0] shift_seek_target,
	input  wire [2:0]            pixel_mode,
	input  wire [3:0]            palette_offset,

	output wire                  load_req,
	input  wire                  load_ack,
	input  wire [W_DATA-1:0]     load_data,

	output wire [W_PIX_MAX-1:0]  out_data,
	output wire                  out_alpha,
	output wire                  out_vld,
	input  wire                  out_rdy
);

`include "riscboy_ppu_const.vh"

wire [2:0] pixel_log_size = MODE_LOG_PIXSIZE(pixel_mode);
wire [4:0] pixel_size_bits = 5'h1 << pixel_log_size;

wire [W_PIX_MAX-1:0]  shift_out;
reg  [W_SHIFTCTR-1:0] shift_ctr;
wire [W_SHIFTCTR-1:0] shift_ctr_next;
wire                  shift_ctr_carryout;
assign {shift_ctr_carryout, shift_ctr_next} = shift_ctr + pixel_size_bits;

// "Seek": rapid log-time shift through the bus data when getting back into
// steady state after flush.
// To seek, we shift by the highest bit-weight first, to maintain the
// invariant that total shift count is aligned on a boundary of next shift
// amount. Do this by shifting a 1-bit mask from left to right of ctr.
// Can then load the target into the ctr when done.
reg                   shift_empty;
reg                   shift_seeking;

wire [W_SHIFTCTR-1:0] seek_shamt = shift_seek_target & shift_ctr;
wire seek_end = shift_ctr[0];

wire [W_SHIFTCTR-1:0] shamt_dec = shift_seeking ? seek_shamt : shift_ctr_next & ~shift_ctr;
wire                  shift_en = (shift_seeking && |seek_shamt) || (out_vld && out_rdy);
wire [W_SHAMT-1:0]    shamt;

onehot_encoder #(
	.W_INPUT(W_SHIFTCTR)
) shamt_encoder (
	.in  (shamt_dec),
	.out (shamt)
);

riscboy_ppu_pixel_gearbox #(
	.W_DATA(W_DATA),
	.W_PIX_MIN(1),
	.W_PIX_MAX(W_PIX_MAX)
) gearbox_u (
	.clk     (clk),
	.rst_n   (rst_n),
	.din     (load_data),
	.din_vld (load_ack),
	.shamt   ((shamt + {{W_SHAMT-1{1'b0}}, 1'b1}) & {W_SHAMT{shift_en}}),
	.dout    (shift_out)
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		shift_ctr <= {W_SHIFTCTR{1'b0}};
		shift_seeking <= 1'b0;
		shift_empty <= 1'b1;
	end else if (flush) begin
		shift_ctr <= {flush_unaligned, {W_SHIFTCTR-1{1'b0}}};
		shift_seeking <= flush_unaligned;
		shift_empty <= 1'b1;
	end else if (shift_empty) begin
		shift_empty <= !load_ack;
	end else if (shift_seeking) begin
		shift_seeking <= !seek_end;
		if (seek_end)
			shift_ctr <= shift_seek_target;
		else
			shift_ctr <= shift_ctr >> 1;
	end else begin
		shift_empty <= shift_en && shift_ctr_carryout;
		if (shift_en) begin
			shift_ctr <= shift_ctr_next;
		end
	end
end

wire [7:0] palette_mask =
	pixel_mode == PIXMODE_PAL1 ? 8'h1 :
	pixel_mode == PIXMODE_PAL2 ? 8'h3 :
	pixel_mode == PIXMODE_PAL4 ? 8'hf : 8'hff;

wire [W_PIX_MAX-1:0] pixdata_masked = {
	shift_out[W_PIX_MAX-1:8],
	shift_out[7:0] & palette_mask
};

wire [W_PIX_MAX-1:0] pixdata_masked_offset = {
	pixdata_masked[W_PIX_MAX-1:8],
	pixdata_masked[7:0] | {palette_offset, 4'h0}
};

assign out_data = pixdata_masked_offset;
assign out_alpha =
	pixel_mode[2] ? |pixdata_masked[7:0] :
	pixel_mode[1] ? shift_out[7] : shift_out[15];

assign load_req = shift_empty;
assign out_vld = !(shift_empty || shift_seeking);

endmodule
