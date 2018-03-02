/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2018 Luke Wren                                       *
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

// Instantiate JumpLite NoC switches to create directed torus busfabric
//
// Use of huge vectors in ports makes this tricky to use by hand;
// use the busfabric generator tool.

module jumplite_torus #(
	parameter W_HADDR = 32,
	parameter W_DATA = 32,
	parameter N_X = 3,
	parameter N_Y = 3,
	localparam W_XADDR = $clog2(N_X),
	localparam W_YADDR = $clog2(N_Y)
) (
	input wire clk,
	input wire rst_n,

	input wire  [N_X * N_Y * W_XADDR-1:0] i_src_naddr_x,
	input wire  [N_X * N_Y * W_YADDR-1:0] i_src_naddr_y,
	input wire  [N_X * N_Y * W_XADDR-1:0] i_dst_naddr_x,
	input wire  [N_X * N_Y * W_YADDR-1:0] i_dst_naddr_y,
	input wire  [N_X * N_Y * W_HADDR-1:0] i_haddr,
	input wire  [N_X * N_Y * W_DATA-1 :0] i_data,
	input wire  [N_X * N_Y * 2-1      :0] i_trans,
	output wire [N_X * N_Y - 1        :0] i_ready,
	
	output wire [N_X * N_Y * W_XADDR-1:0] o_src_naddr_x,
	output wire [N_X * N_Y * W_YADDR-1:0] o_src_naddr_y,
	output wire [N_X * N_Y * W_XADDR-1:0] o_dst_naddr_x,
	output wire [N_X * N_Y * W_YADDR-1:0] o_dst_naddr_y,
	output wire [N_X * N_Y * W_HADDR-1:0] o_haddr,
	output wire [N_X * N_Y * W_DATA-1 :0] o_data,
	output wire [N_X * N_Y * 2-1      :0] o_trans,
	input  wire [N_X * N_Y - 1        :0] o_eject
	
);

genvar i, j;

wire [W_XADDR-1:0] horz_src_naddr_x [0:N_X-1][0:N_Y-1];
wire [W_YADDR-1:0] horz_src_naddr_y [0:N_X-1][0:N_Y-1];
wire [W_XADDR-1:0] horz_dst_naddr_x [0:N_X-1][0:N_Y-1];
wire [W_YADDR-1:0] horz_dst_naddr_y [0:N_X-1][0:N_Y-1];
wire [W_HADDR-1:0] horz_haddr       [0:N_X-1][0:N_Y-1];
wire [W_DATA-1 :0] horz_data        [0:N_X-1][0:N_Y-1];
wire [2-1      :0] horz_trans       [0:N_X-1][0:N_Y-1];

wire [W_XADDR-1:0] vert_src_naddr_x [0:N_X-1][0:N_Y-1];
wire [W_YADDR-1:0] vert_src_naddr_y [0:N_X-1][0:N_Y-1];
wire [W_XADDR-1:0] vert_dst_naddr_x [0:N_X-1][0:N_Y-1];
wire [W_YADDR-1:0] vert_dst_naddr_y [0:N_X-1][0:N_Y-1];
wire [W_HADDR-1:0] vert_haddr       [0:N_X-1][0:N_Y-1];
wire [W_DATA-1 :0] vert_data        [0:N_X-1][0:N_Y-1];
wire [2-1      :0] vert_trans       [0:N_X-1][0:N_Y-1];


generate
for (i = 0; i < N_X; i = i + 1) begin
	for (j = 0; j < N_Y; j = j + 1) begin
		jumplite_switch #(
			.W_XADDR(W_XADDR),
			.W_YADDR(W_YADDR),
			.W_HADDR(W_HADDR),
			.W_DATA(W_DATA),
			.NADDR_X(i),
			.NADDR_Y(j),
		) switch (
			.clk(clk),
			.rst_n(rst_n),

			.xi_src_naddr_x (horz_src_naddr_x[i][j]),
			.xi_src_naddr_y (horz_src_naddr_y[i][j]),
			.xi_dst_naddr_x (horz_dst_naddr_x[i][j]),
			.xi_dst_naddr_y (horz_dst_naddr_y[i][j]),
			.xi_haddr       (horz_haddr      [i][j]),
			.xi_data        (horz_data       [i][j]),
			.xi_trans       (horz_trans      [i][j]),

			.yi_src_naddr_x (vert_src_naddr_x[i][j]),
			.yi_src_naddr_y (vert_src_naddr_y[i][j]),
			.yi_dst_naddr_x (vert_dst_naddr_x[i][j]),
			.yi_dst_naddr_y (vert_dst_naddr_y[i][j]),
			.yi_haddr       (vert_haddr      [i][j]),
			.yi_data        (vert_data       [i][j]),
			.yi_trans       (vert_trans      [i][j]),
			.yi_eject       (o_eject[N_Y * (j ? j - 1 : N_Y-1) + i]),

			.m_src_naddr_x  (i_src_naddr_x [(N_Y * j + i) * W_XADDR +: W_XADDR]),
			.m_src_naddr_y  (i_src_naddr_y [(N_Y * j + i) * W_YADDR +: W_YADDR]),
			.m_dst_naddr_x  (i_dst_naddr_x [(N_Y * j + i) * W_XADDR +: W_XADDR]),
			.m_dst_naddr_y  (i_dst_naddr_y [(N_Y * j + i) * W_YADDR +: W_YADDR]),
			.m_haddr        (i_haddr       [(N_Y * j + i) * W_HADDR +: W_HADDR]),
			.m_data         (i_data        [(N_Y * j + i) * W_DATA  +: W_DATA ]),
			.m_trans        (i_trans       [(N_Y * j + i) * 2       +: 2      ]),
			.m_ready        (i_ready       [(N_Y * j + i) * 1       +: 1      ]),

			.xo_src_naddr_x (horz_src_naddr_x[(i + 1) % N_X][j]),
			.xo_src_naddr_y (horz_src_naddr_y[(i + 1) % N_X][j]),
			.xo_dst_naddr_x (horz_dst_naddr_x[(i + 1) % N_X][j]),
			.xo_dst_naddr_y (horz_dst_naddr_y[(i + 1) % N_X][j]),
			.xo_haddr       (horz_haddr      [(i + 1) % N_X][j]),
			.xo_data        (horz_data       [(i + 1) % N_X][j]),
			.xo_trans       (horz_trans      [(i + 1) % N_X][j]),

			.yo_src_naddr_x (vert_src_naddr_x[i][(j + 1) % N_Y]),
			.yo_src_naddr_y (vert_src_naddr_y[i][(j + 1) % N_Y]),
			.yo_dst_naddr_x (vert_dst_naddr_x[i][(j + 1) % N_Y]),
			.yo_dst_naddr_y (vert_dst_naddr_y[i][(j + 1) % N_Y]),
			.yo_haddr       (vert_haddr      [i][(j + 1) % N_Y]),
			.yo_data        (vert_data       [i][(j + 1) % N_Y]),
			.yo_trans       (vert_trans      [i][(j + 1) % N_Y])
		);

		assign o_src_naddr_x [(N_Y * j + i) * W_XADDR +: W_XADDR] = vert_src_naddr_x[i][(j + 1) % N_Y];
		assign o_src_naddr_y [(N_Y * j + i) * W_YADDR +: W_YADDR] = vert_src_naddr_y[i][(j + 1) % N_Y];
		assign o_dst_naddr_x [(N_Y * j + i) * W_XADDR +: W_XADDR] = vert_dst_naddr_x[i][(j + 1) % N_Y];
		assign o_dst_naddr_y [(N_Y * j + i) * W_YADDR +: W_YADDR] = vert_dst_naddr_y[i][(j + 1) % N_Y];
		assign o_haddr       [(N_Y * j + i) * W_HADDR +: W_HADDR] = vert_haddr      [i][(j + 1) % N_Y];
		assign o_data        [(N_Y * j + i) * W_DATA  +: W_DATA ] = vert_data       [i][(j + 1) % N_Y];
		assign o_trans       [(N_Y * j + i) * 2       +: 2      ] = vert_trans      [i][(j + 1) % N_Y];

	end
end
endgenerate

endmodule