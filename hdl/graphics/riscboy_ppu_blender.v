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

// Each pixel generating device (sprite or background) generates a request.
// These requests are blended together based on layer priority and
// transparency to produce a single output pixel.
//
// Each request consists of:
// - A valid/ready handshake, determining if a pixel is consumed. Note that
//   ready will be a combinatorial function of valid, as we do not consume a
//   pixel until *all* requesters present one.
// - An "alpha" bit. 0 means transparent, i.e. the requester waives its right
//   to be blended into this output pixel. 1 means opaque.
// - 15 colour bits. May contain up to RGB555 data, or a palette index.
// - 2 mode bits. The modes are:
//     - 0: RGB555
//     - 1: RGB232
//     - 2: Paletted
// - A layer select, from 0...N_LAYERS-1. Higher layers are given higher priority
//   over lower layers for final output blending. On a tie, the lowest-numbered
//   request wins.
//
// Masking and offset of the palette index is performed before
// reaching the blender.

module riscboy_ppu_blender #(
	parameter N_REQ      = 1,
	parameter N_LAYERS   = 1,
	// Do not modify the below. It will not result in working hardware.
	parameter W_PIXDATA  = 15,
	parameter W_MODE     = 2,
	parameter W_LAYERSEL = N_LAYERS > 1 ? $clog2(N_LAYERS) : 1
) (

	input  wire [N_REQ-1:0]            req_vld,
	output wire [N_REQ-1:0]            req_rdy,
	input  wire [N_REQ-1:0]            req_alpha,
	input  wire [W_PIXDATA*N_REQ-1:0]  req_pixdata,
	input  wire [W_MODE*N_REQ-1:0]     req_mode,
	input  wire [W_LAYERSEL*N_REQ-1:0] req_layer,

	input  wire [W_PIXDATA-1:0]        default_bg_colour,

	output wire                        out_vld,
	input  wire                        out_rdy,
	output wire [W_PIXDATA-1:0]        out_pixdata,
	output wire                        out_paletted
);

// ----------------------------------------------------------------------------
// Handshaking

assign out_vld = &req_vld;
assign req_rdy = {N_REQ{out_rdy && &req_vld}};

// ----------------------------------------------------------------------------
// Request Arbitration

// Start by collating all the external request vectors, and an additional dummy
// request for the background colour.

localparam W_REQDATA = W_PIXDATA + W_MODE;

reg [(N_REQ + 1) * W_REQDATA - 1 : 0] reqdata;

always @ (*) begin: collate_reqs
	integer i;
	for (i = 0; i < N_REQ; i = i + 1) begin
		reqdata[i * W_REQDATA +: W_REQDATA] = {
			req_mode[i * W_MODE +: W_MODE],
			req_pixdata[i * W_PIXDATA +: W_PIXDATA]
		};
	end
	reqdata[N_REQ * W_REQDATA +: W_REQDATA] = {{W_MODE{1'b0}}, default_bg_colour};
}

// Find the highest-priority pixel source on the highest layer. Default BG
// colour is implicitly on layer 0.

wire [N_REQ  :0] src_gnt;

onehot_priority_dynamic #(
	.N_REQ        (N_REQ + 1),
	.N_PRIORITIES (N_LAYERS),
	.HIGHEST_WINS (1)
) pixel_arbiter (
	.priority ({{W_LAYERSEL{1'b0}}, req_layer}),
	.req      (req_alpha),
	.gnt      (src_gnt)
);

// Then mux in the pixel data and mode from that source.

wire [W_REQDATA-1:0] reqdata_blended;

onehot_mux #(
	.N_INPUTS (N_REQ + 1),
	.W_INPUT  (W_REQDATA)
) pixel_mux (
	.in  (reqdata),
	.sel (src_gnt),
	.out (reqdata_blended)
);

// ----------------------------------------------------------------------------
// Pixel modes

// For RGB555 and paletted, we simply pass all the pixel data through,
// and indicate whether it is paletted or not.
// RGB232 must be expanded to RGB555, and we do that here.
//
// The final expansion to e.g. RGB565 or RGB888 for the display is handled
// after paletting. It is not our concern, since it's an LCD detail.

wire [W_MODE-1:0]    mode_blended;
wire [W_PIXDATA-1:0] pixdata_blended;
assign {mode_blended, pixdata_blended} = reqdata_blended;
	
assign out_pixdata = mode_blended == 2'h1 ? 
	{pixdata_blended[7:6], 3'h0, pixdata_blended[5:3], 2'h0, pixdata_blended[1:0], 3'h0} :
	pixdata_blended;

assign out_paletted = mode_blended[1];

endmodule
