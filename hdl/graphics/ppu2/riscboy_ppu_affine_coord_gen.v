/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2020 Luke Wren                                       *
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

// Calculate u vectors from the following transform:
//
// u = A(s - s0) + b
//
// Where s initially takes any value, but then increments by 1 in the x
// direction. We need to do a matrix multiply to get started, but the
// increment assumption means we can get away with addition the rest of the
// time, and produce one uv coordinate per clock.
//
// u = [ u ]   s - s0 = [ raster_offs_x ]   A = [ a_xu  a_yu ]   b = [ b_u ]
//     [ v ]            [ raster_offs_y ]       [ a_xv  a_yv ]       [ b_v ]

module riscboy_ppu_affine_coord_gen #(
	parameter W_COORD_INT = 10,
	parameter W_COORD_FRAC = 8,
	parameter W_BUS_DATA = 32
) (
	input  wire                   clk,
	input  wire                   rst_n,

	input  wire                   start_affine,
	input  wire                   start_simple,
	input  wire [W_COORD_INT-1:0] raster_offs_x, // (s - s0)
	input  wire [W_COORD_INT-1:0] raster_offs_y,

	input  wire [W_BUS_DATA-1:0]  aparam_data,   // b vector, then A matrix, upper row first
	input  wire                   aparam_vld,
	output wire                   aparam_rdy,

	output wire [W_COORD_INT-1:0] out_u,
	output wire [W_COORD_INT-1:0] out_v,
	output wire                   out_vld,
	input  wire                   out_rdy
);

localparam W_STATE         = 3;
localparam S_STREAM_SIMPLE = 3'h0;
localparam S_APARAM0       = 3'h1;
localparam S_APARAM1       = 3'h2;
localparam S_APARAM2       = 3'h3;
localparam S_MAT_MUL       = 3'h4;
localparam S_STREAM_AFFINE = 3'h5;

parameter W_MULCTR = $clog2(W_COORD_INT);

reg [W_STATE-1:0]  state;
reg [W_MULCTR-1:0] mul_ctr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		state <= S_STREAM_SIMPLE;
		mul_ctr <= {W_MULCTR{1'b0}};
	end else if (start_simple) begin
		state <= S_STREAM_SIMPLE;
	end else if (start_affine) begin
		state <= S_APARAM0;
	end else case (state)
		S_APARAM0: if (aparam_vld && aparam_rdy) state <= S_APARAM1;
		S_APARAM1: if (aparam_vld && aparam_rdy) state <= S_APARAM2;
		S_APARAM2: if (aparam_vld && aparam_rdy) begin
			state <= S_MAT_MUL;
			mul_ctr <= W_COORD_INT - 1;
		end
		S_MAT_MUL: begin
			mul_ctr <= mul_ctr - 1'b1;
			if (~|mul_ctr)
				state <= S_STREAM_AFFINE;
		end
		default: begin end
	endcase
end

reg [W_COORD_INT-1:0] raster_offs_x_sreg;
reg [W_COORD_INT-1:0] raster_offs_y_sreg;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		raster_offs_x_sreg <= {W_COORD_FULL{1'b0}};
		raster_offs_y_sreg <= {W_COORD_FULL{1'b0}};
	end else if (start_affine) begin
		raster_offs_x_sreg <= raster_offs_x;
		raster_offs_y_sreg <= raster_offs_y;
	end else if (state == S_MAT_MUL) begin
		raster_offs_x_sreg <= raster_offs_x_sreg >> 1;
		raster_offs_y_sreg <= raster_offs_y_sreg >> 1;
	end
end

assign aparam_rdy = state == S_APARAM0 || state == S_APARAM1 || state == S_APARAM2;
assign out_vld = state == S_STREAM_SIMPLE || state == S_STREAM_AFFINE;

// ----------------------------------------------------------------------------
// u and v phase accumulators

localparam W_COORD_FULL = W_COORD_INT + W_COORD_FRAC;
localparam W_APARAM = W_BUS_DATA / 2;

// b coefficients are left-shifted to full significance
wire [W_COORD_FULL-1:0] aparam_unpack_bu = {aparam_data[       0 +: W_APARAM], {W_COORD_FULL-W_APARAM{1'b0}}};
wire [W_COORD_FULL-1:0] aparam_unpack_bv = {aparam_data[W_APARAM +: W_APARAM], {W_COORD_FULL-W_APARAM{1'b0}}};
// A coefficients are sign-extended to full size. First a_xu, a_yu,  then  a_xv, a_yv.
wire [W_COORD_FULL-1:0] aparam_unpack_ax = {{W_COORD_FULL-W_APARAM{aparam_data[  W_APARAM-1]}}, aparam_data[       0 +: W_APARAM]};
wire [W_COORD_FULL-1:0] aparam_unpack_ay = {{W_COORD_FULL-W_APARAM{aparam_data[2*W_APARAM-1]}}, aparam_data[W_APARAM +: W_APARAM]};

wire accum_load = state == S_APARAM0 && aparam_vld && aparam_rdy || start_simple;
wire op_load_u  = state == S_APARAM1 && aparam_vld && aparam_rdy;
wire op_load_v  = state == S_APARAM2 && aparam_vld && aparam_rdy;

wire [W_COORD_FULL-1:0] accum_wdata_u = {
	start_simple ? raster_offs_x : aparam_unpack_bu[W_COORD_FRAC +: W_COORD_INT],
	aparam_unpack_bu[0 +: W_COORD_FRAC]
};
wire [W_COORD_FULL-1:0] accum_wdata_v = {
	start_simple ? raster_offs_y : aparam_unpack_bv[W_COORD_FRAC +: W_COORD_INT],
	aparam_unpack_bv[0 +: W_COORD_FRAC]
};

wire op_shift     = state == S_MAT_MUL &&  |mul_ctr;
wire op_a_unshift = state == S_MAT_MUL && ~|mul_ctr;
wire accum_add_a  = state == S_MAT_MUL && raster_offs_x_sreg[0] || state == S_STREAM_AFFINE && out_vld && out_rdy;
wire accum_add_b  = state == S_MAT_MUL && raster_offs_y_sreg[0];
wire accum_u_incr = state == S_STREAM_SIMPLE && out_vld && out_rdy;

wire [W_COORD_FULL-1:0] phase_u;
wire [W_COORD_FULL-1:0] phase_v;

riscboy_ppu_phase_accum #(
	.W_COORD_INT  (W_COORD_INT),
	.W_COORD_FRAC (W_COORD_FRAC)
) u_phase_accum (
	.clk          (clk),
	.rst_n        (rst_n),

	.op_a_wdata   (aparam_unpack_ax),
	.op_a_load    (op_load_u),
	.op_a_unshift (op_a_unshift),
	.op_b_wdata   (aparam_unpack_ay),
	.op_b_load    (op_load_u),
	.op_shift     (op_shift),

	.accum_wdata  (accum_wdata_u),
	.accum_load   (accum_load),
	.accum_add_a  (accum_add_a),
	.accum_add_b  (accum_add_b),
	.accum_incr   (accum_u_incr),
	.accum        (phase_u)
);

riscboy_ppu_phase_accum #(
	.W_COORD_INT  (W_COORD_INT),
	.W_COORD_FRAC (W_COORD_FRAC)
) v_phase_accum (
	.clk          (clk),
	.rst_n        (rst_n),

	.op_a_wdata   (aparam_unpack_ax),
	.op_a_load    (op_load_v),
	.op_a_unshift (op_a_unshift),
	.op_b_wdata   (aparam_unpack_ay),
	.op_b_load    (op_load_v),
	.op_shift     (op_shift),

	.accum_wdata  (accum_wdata_v),
	.accum_load   (accum_load),
	.accum_add_a  (accum_add_a),
	.accum_add_b  (accum_add_b),
	.accum_incr   (1'b0),
	.accum        (phase_v)
);

assign out_u = phase_u[W_COORD_FRAC +: W_COORD_INT];
assign out_v = phase_v[W_COORD_FRAC +: W_COORD_INT];

endmodule
