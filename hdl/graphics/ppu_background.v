

module ppu_background #(
	parameter W_COORD = 12,
	parameter W_LOG_COORD = $clog2(W_COORD),
	parameter W_LOG_LOG_COORD = $clog2(W_LOG_COORD), // trust me
	parameter W_OUTDATA = 15,
	parameter W_ADDR = 32
) (
	input  wire                        clk,
	input  wire                        rst_n,

	input  wire                        en,
	input  wire                        flush,

	input  wire [W_COORD-1:0]          beam_x,
	input  wire [W_COORD-1:0]          beam_y,

	// Config signals -- source tbd
	input  wire [W_COORD-1:0]          cfg_scroll_x,
	input  wire [W_COORD-1:0]          cfg_scroll_y,
	input  wire [W_LOG_COORD-1:0]      cfg_log_w,
	input  wire [W_LOG_COORD-1:0]      cfg_log_h,
	input  wire [W_ADDR-1:0]           cfg_tileset_base,
	input  wire [W_ADDR-1:0]           cfg_tilemap_base,
	input  wire [W_LOG_LOG_COORD-1:0]  cfg_loglog_tileset_width,
	input  wire [W_LOG_LOG_COORD-1:0]  cfg_loglog_tilemap_width,
	input  wire [1:0]                  cfg_log_tile_size,
	input  wire [2:0]                  cfg_pixel_mode,
	input  wire                        cfg_transparency,

	output wire                        out_vld,
	input  wire                        out_rdy,
	output wire [W_OUTDATA-1:0]        out_pixdata,
	output wire                        out_paletted
);

// Pixel's location in the background coordinate system
reg [W_COORD-1:0] u;
reg [W_COORD-1:0] v;

wire [W_COORD-1:0] w_mask = ~({{W_COORD{1'b1}}, 1'b0} << log_w}};
wire [W_COORD-1:0] h_mask = ~({{W_COORD{1'b1}}, 1'b0} << log_h}};

always @ (posedge clk) begin
	if (!rst_n) begin
		u <= {W_COORD{1'b0}};
		v <= {W_COORD{1'b0}};
	end else if (flush) begin
		u <= (beam_x + scroll_x) & w_mask;
		v <= (beam_y + scroll_y) & h_mask;
	end else if (out_vld && out_rdy) begin
		u <= (u + 1'b1) & w_mask;
	end
end

wire [2:0] pixel_log_size = MODE_LOG_PIXSIZE(pixel_mode);

wire [4:0] pixel_size_bits = 5'h1 << log_pixel_size;
wire [5:0] tile_size_pixels = 6'h4 << log_tile_size;

wire 
