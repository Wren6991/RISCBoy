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

// JumpLite NoC Switch

//
//               |
//               | 
//               V
//       +----------------+
//       |       YI       |
//       |                |
//       |                |
// ----->| XI          XO |----->
//       |                |
//       |             M  |<-----
//       |       YO       |
//       +----------------+
//               |
//               |
//               V
//
// Routes XI, YI, M to YO, XO
// Rules:
// - Packets want to go X-ward until their X address matches, then they
//   want to go Y-ward
// - Packets coming from YI take precedence, then XI, then M
// - If XI and YI contend, YI takes precedence, and XI is deflected to the port
//   it didn't want.
// - If M contends, it is stalled


module jumplite_switch #(
	parameter W_XADDR = 3,
	parameter W_YADDR = 3,
	parameter W_HADDR = 32,
	parameter W_DATA  = 32,
	// This node's own address:
	parameter NADDR_X = 0,
	parameter NADDR_Y = 0
) (
	// Globals
	input wire clk,
	input wire rst_n,

	// X input port
	input wire [W_XADDR-1:0] xi_src_naddr_x,
	input wire [W_YADDR-1:0] xi_src_naddr_y,
	input wire [W_XADDR-1:0] xi_dst_naddr_x,
	input wire [W_YADDR-1:0] xi_dst_naddr_y,
	input wire [W_HADDR-1:0] xi_haddr,
	input wire [W_DATA-1:0]  xi_data,
	input wire [1:0]         xi_trans,
	
	// Y input port
	input wire [W_XADDR-1:0] yi_src_naddr_x,
	input wire [W_YADDR-1:0] yi_src_naddr_y,
	input wire [W_XADDR-1:0] yi_dst_naddr_x,
	input wire [W_YADDR-1:0] yi_dst_naddr_y,
	input wire [W_HADDR-1:0] yi_haddr,
	input wire [W_DATA-1:0]  yi_data,
	input wire [1:0]         yi_trans,
	// Cause switch to swallow data on Y input:
	input wire               yi_eject,
	
	// Master input port
	input wire [W_XADDR-1:0] m_src_naddr_x,
	input wire [W_YADDR-1:0] m_src_naddr_y,
	input wire [W_XADDR-1:0] m_dst_naddr_x,
	input wire [W_YADDR-1:0] m_dst_naddr_y,
	input wire [W_HADDR-1:0] m_haddr,
	input wire [W_DATA-1:0]  m_data,
	input wire [1:0]         m_trans,
	output wire              m_ready,

	// X output port
	output reg [W_XADDR-1:0] xo_src_naddr_x,
	output reg [W_YADDR-1:0] xo_src_naddr_y,
	output reg [W_XADDR-1:0] xo_dst_naddr_x,
	output reg [W_YADDR-1:0] xo_dst_naddr_y,
	output reg [W_HADDR-1:0] xo_haddr,
	output reg [W_DATA-1:0]  xo_data,
	output reg [1:0]         xo_trans,

	// Y output port
	output reg [W_XADDR-1:0] yo_src_naddr_x,
	output reg [W_YADDR-1:0] yo_src_naddr_y,
	output reg [W_XADDR-1:0] yo_dst_naddr_x,
	output reg [W_YADDR-1:0] yo_dst_naddr_y,
	output reg [W_HADDR-1:0] yo_haddr,
	output reg [W_DATA-1:0]  yo_data,
	output reg [1:0]         yo_trans	
);


localparam TRANS_IDLE = 2'b00;
localparam TRANS_WRITE = 2'b01;
localparam TRANS_READ_ADDR = 2'b10;
localparam TRANS_WRITE_ADDR = 2'b11;

wire xi_req = |xi_trans;
wire yi_req = |yi_trans && !yi_eject;
wire m_req  = |m_trans;

assign m_ready = !(xi_req && yi_req);

wire xi_req_x = xi_req && xi_dst_naddr_x != NADDR_X;
wire xi_req_y = xi_req && xi_dst_naddr_x == NADDR_X;
wire yi_req_x = yi_req && yi_dst_naddr_x != NADDR_X;
wire yi_req_y = yi_req && yi_dst_naddr_x == NADDR_X;
wire m_req_x  = m_req  && m_dst_naddr_x  != NADDR_X;
wire m_req_y  = m_req  && m_dst_naddr_x  == NADDR_X;

// X output

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		xo_dst_naddr_x <= {W_XADDR{1'b0}};
		xo_dst_naddr_y <= {W_YADDR{1'b0}};
		xo_src_naddr_x <= {W_XADDR{1'b0}};
		xo_src_naddr_y <= {W_YADDR{1'b0}};
		xo_haddr <= {W_HADDR{1'b0}};
		xo_data <= {W_DATA{1'b0}};
		xo_trans <= TRANS_IDLE;
	end else begin
		if (yi_req_x) begin
			xo_dst_naddr_x <= yi_dst_naddr_x;
			xo_dst_naddr_y <= yi_dst_naddr_y;
			xo_src_naddr_x <= yi_src_naddr_x;
			xo_src_naddr_y <= yi_src_naddr_y;
			xo_haddr       <= yi_haddr;
			xo_data        <= yi_data;
			xo_trans       <= yi_trans;
		end else if (xi_req_x || (xi_req_y && yi_req_y)) begin
			xo_dst_naddr_x <= xi_dst_naddr_x;
			xo_dst_naddr_y <= xi_dst_naddr_y;
			xo_src_naddr_x <= xi_src_naddr_x;
			xo_src_naddr_y <= xi_src_naddr_y;
			xo_haddr       <= xi_haddr;
			xo_data        <= xi_data;
			xo_trans       <= xi_trans;
		end else if (m_req_x || (m_req_y && (xi_req_y || yi_req_y))) begin
			xo_dst_naddr_x <= m_dst_naddr_x;
			xo_dst_naddr_y <= m_dst_naddr_y;
			xo_src_naddr_x <= m_src_naddr_x;
			xo_src_naddr_y <= m_src_naddr_y;
			xo_haddr       <= m_haddr;
			xo_data        <= m_data;
			xo_trans       <= m_trans;			
		end else begin
			xo_dst_naddr_x <= {W_XADDR{1'b0}};
			xo_dst_naddr_y <= {W_YADDR{1'b0}};
			xo_src_naddr_x <= {W_XADDR{1'b0}};
			xo_src_naddr_y <= {W_YADDR{1'b0}};
			xo_haddr <= {W_HADDR{1'b0}};
			xo_data <= {W_DATA{1'b0}};
			xo_trans <= TRANS_IDLE;
		end
	end
end

// Y output

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		yo_dst_naddr_x <= {W_XADDR{1'b0}};
		yo_dst_naddr_y <= {W_YADDR{1'b0}};
		yo_src_naddr_x <= {W_XADDR{1'b0}};
		yo_src_naddr_y <= {W_YADDR{1'b0}};
		yo_haddr <= {W_HADDR{1'b0}};
		yo_data <= {W_DATA{1'b0}};
		yo_trans <= TRANS_IDLE;
	end else begin
		if (yi_req_y) begin
			yo_dst_naddr_x <= yi_dst_naddr_x;
			yo_dst_naddr_y <= yi_dst_naddr_y;
			yo_src_naddr_x <= yi_src_naddr_x;
			yo_src_naddr_y <= yi_src_naddr_y;
			yo_haddr       <= yi_haddr;
			yo_data        <= yi_data;
			yo_trans       <= yi_trans;
		end else if (xi_req_y) begin
			yo_dst_naddr_x <= xi_dst_naddr_x;
			yo_dst_naddr_y <= xi_dst_naddr_y;
			yo_src_naddr_x <= xi_src_naddr_x;
			yo_src_naddr_y <= xi_src_naddr_y;
			yo_haddr       <= xi_haddr;
			yo_data        <= xi_data;
			yo_trans       <= xi_trans;
		end else if (m_req_y) begin
			yo_dst_naddr_x <= m_dst_naddr_x;
			yo_dst_naddr_y <= m_dst_naddr_y;
			yo_src_naddr_x <= m_src_naddr_x;
			yo_src_naddr_y <= m_src_naddr_y;
			yo_haddr       <= m_haddr;
			yo_data        <= m_data;
			yo_trans       <= m_trans;			
		end else begin
			yo_dst_naddr_x <= {W_XADDR{1'b0}};
			yo_dst_naddr_y <= {W_YADDR{1'b0}};
			yo_src_naddr_x <= {W_XADDR{1'b0}};
			yo_src_naddr_y <= {W_YADDR{1'b0}};
			yo_haddr <= {W_HADDR{1'b0}};
			yo_data <= {W_DATA{1'b0}};
			yo_trans <= TRANS_IDLE;
		end
	end
end

endmodule