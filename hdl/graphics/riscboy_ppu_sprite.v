module riscboy_ppu_sprite #(
	parameter W_DATA = 32,
	parameter W_OUTDATA = 15,
	parameter W_COORD = 10,
	// Driven parameters:
	parameter W_SHIFTCTR = $clog2(W_DATA)
) (
	input  wire                  clk,
	input  wire                  rst_n,

	input  wire                  flush,
	input  wire                  en,

	input  wire [2:0]            cfg_pixel_mode,
	input  wire [3:0]            cfg_palette_offs,

	output wire                  agu_req,
	input  wire                  agu_ack,
	input  wire                  agu_active,
	input  wire [W_COORD-1:0]    agu_x_precount,
	input  wire [4:0]            agu_x_postcount,
	input  wire [W_SHIFTCTR-1:0] agu_shift_seek_target,

	output wire                  bus_vld,
	input  wire                  bus_rdy,
	output wire [4:0]            bus_postcount,
	input  wire [W_DATA-1:0]     bus_data,

	output wire                  out_vld,
	input  wire                  out_rdy,
	output wire                  out_alpha,
	output wire [W_OUTDATA-1:0]  out_pixdata
);

localparam W_PIX_MAX = W_OUTDATA + 1;

reg                  need_agu_resp;
reg [W_SHIFTCTR-1:0] shift_seek_target;
reg                  active_this_scanline;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		need_agu_resp <= 1'b0;
		shift_seek_target <= {W_SHIFTCTR{1'b0}};
		active_this_scanline <= 1'b0;
	end else if (flush) begin
		need_agu_resp <= 1'b1;
	end else if (agu_ack) begin
		need_agu_resp <= 1'b0;
		shift_seek_target <= agu_shift_seek_target;
		active_this_scanline <= agu_active;
	end
end

assign agu_req = en && need_agu_resp;

reg [W_COORD-1:0] x_precount;
reg [4:0]         x_postcount;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		x_precount <= {W_COORD{1'b0}};
		x_postcount <= {5{1'b0}};
	end else if (agu_ack) begin
		x_precount <= agu_x_precount;
		x_postcount <= agu_x_postcount;		
	end else if (out_vld && out_rdy) begin
		if (|x_precount)
			x_precount <= x_precount - 1'b1;
		else if (|x_postcount)
			x_postcount <= x_postcount - 1'b1;
	end
end


// ----------------------------------------------------------------------------
// Pixel streamer

wire                  pixel_load_req;
wire                  pixel_load_ack;
wire                  stream_flush = flush || need_agu_resp;

wire [W_PIX_MAX-1:0]  pixel_data;
wire                  pixel_alpha;
wire                  pixel_vld;
wire                  pixel_rdy;

riscboy_ppu_pixel_streamer #(
	.W_DATA(W_DATA),
	.W_PIX_MAX(W_PIX_MAX)
) streamer (
	.clk               (clk),
	.rst_n             (rst_n),

	.flush             (stream_flush),
	.flush_unaligned   (|agu_shift_seek_target),

	.shift_seek_target (shift_seek_target),
	.pixel_mode        (cfg_pixel_mode),
	.palette_offset    (cfg_palette_offs),

	.load_req          (pixel_load_req),
	.load_ack          (pixel_load_ack),
	.load_data         (bus_data),

	.out_data          (pixel_data),
	.out_alpha         (pixel_alpha),
	.out_vld           (pixel_vld),
	.out_rdy           (pixel_rdy)
);

assign out_pixdata = pixel_data[0 +: W_OUTDATA];
assign out_alpha = en && pixel_alpha;

wire beam_outside_sprite = ~|x_postcount || |x_precount;
assign out_vld = !en || (!need_agu_resp && !flush && (
	beam_outside_sprite || pixel_vld || !active_this_scanline
));
assign pixel_rdy = out_rdy && !beam_outside_sprite;

reg bus_dphase_dirty;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		bus_dphase_dirty <= 1'b0;
	end else begin
		bus_dphase_dirty <= (bus_dphase_dirty || (bus_vld && flush)) && !bus_rdy;
	end
end

assign bus_vld = bus_dphase_dirty || (pixel_load_req && |x_postcount && active_this_scanline && !need_agu_resp);
assign pixel_load_ack = bus_rdy && !bus_dphase_dirty;
assign bus_postcount = x_postcount;

endmodule
