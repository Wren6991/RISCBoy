module tb;

// ----------------------------------------------------------------------------
// DUT

parameter W_COORD = 12;
parameter W_OUTDATA = 15;
parameter W_ADDR = 32;
parameter W_DATA = 32;
parameter W_SHIFTCTR = $clog2(W_DATA);
parameter W_SHAMT = $clog2(W_SHIFTCTR + 1);
parameter W_LOG_COORD = $clog2(W_COORD);
parameter BUS_SIZE_MAX = $clog2(W_DATA) - 3;


reg                      clk;
reg                      rst_n;
reg                      en;
reg                      flush;
reg  [W_COORD-1:0]       beam_x;
reg  [W_COORD-1:0]       beam_y;
reg                      bus_rdy;
reg  [W_DATA-1:0]        bus_data;
reg  [W_COORD-1:0]       cfg_scroll_x;
reg  [W_COORD-1:0]       cfg_scroll_y;
reg  [W_LOG_COORD-1:0]   cfg_log_w;
reg  [W_LOG_COORD-1:0]   cfg_log_h;
reg  [W_ADDR-1:0]        cfg_tileset_base;
reg  [W_ADDR-1:0]        cfg_tilemap_base;
reg  [W_LOG_COORD-1:0]   cfg_log_tileset_width;
reg                      cfg_tile_size;
reg  [2:0]               cfg_pixel_mode;
reg                      cfg_transparency;
reg                      out_rdy;

wire                     bus_vld;
wire [W_ADDR-1:0]        bus_addr;
wire [1:0]               bus_size;

wire                     out_vld;
wire                     out_alpha;
wire [W_OUTDATA-1:0]     out_pixdata;
wire                     out_paletted;

riscboy_ppu_background #(
	.W_COORD(W_COORD),
	.W_OUTDATA(W_OUTDATA),
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA)
) dut (
	.clk                   (clk),
	.rst_n                 (rst_n),
	.en                    (en),
	.flush                 (flush),
	.beam_x                (beam_x),
	.beam_y                (beam_y),
	.bus_vld               (bus_vld),
	.bus_addr              (bus_addr),
	.bus_size              (bus_size),
	.bus_rdy               (bus_rdy),
	.bus_data              (bus_data),
	.cfg_scroll_x          (cfg_scroll_x),
	.cfg_scroll_y          (cfg_scroll_y),
	.cfg_log_w             (cfg_log_w),
	.cfg_log_h             (cfg_log_h),
	.cfg_tileset_base      (cfg_tileset_base),
	.cfg_tilemap_base      (cfg_tilemap_base),
	.cfg_log_tileset_width (cfg_log_tileset_width),
	.cfg_tile_size         (cfg_tile_size),
	.cfg_pixel_mode        (cfg_pixel_mode),
	.cfg_transparency      (cfg_transparency),
	.out_vld               (out_vld),
	.out_rdy               (out_rdy),
	.out_alpha             (out_alpha),
	.out_pixdata           (out_pixdata),
	.out_paletted          (out_paletted)
);

localparam MEM_SIZE_BYTES = 1 << 16;

reg [7:0] mem[0:MEM_SIZE_BYTES-1];

// FIXME randomize wait states and addr sampling delay

always @ (posedge clk) begin
	if (bus_rdy) begin
		bus_rdy <= 1'b0;
	end else if (bus_vld) begin
		bus_rdy <= 1'b1;
		case (bus_size)
			2'h0: bus_data <= {4{mem[bus_addr]}};
			2'h1: begin
				if (bus_addr[0]) begin
					$display("Unaligned transfer");
					$finish;
				end
				bus_data <= {2{mem[bus_addr + 1], mem[bus_addr]}};
			end
			2'h2: begin
				if (bus_addr[1:0]) begin
					$display("Unaligned transfer");
					$finish;
				end
				bus_data <= {mem[bus_addr + 3], mem[bus_addr + 2], mem[bus_addr + 1], mem[bus_addr]};
			end
			default: begin
				$display("Invalid bus size");
				$finish;
			end
		endcase
	end
end

// ----------------------------------------------------------------------------
// Stimulus

localparam CLK_PERIOD = 10.0;
always #(0.5 * CLK_PERIOD) clk = !clk;

localparam TILESET_OFFS = 16'h4000;
localparam TILEMAP_OFFS = 16'h8000;

initial begin: stimulus
	integer i;
	clk = 0;
	rst_n = 0;
	en = 0;
	flush = 0;
	beam_x = 0;
	beam_y = 0;
	bus_rdy = 0;
	bus_data = 0;
	cfg_scroll_x = 0;
	cfg_scroll_y = 0;
	cfg_log_w = 6;
	cfg_log_h = 6;
	cfg_tileset_base = TILESET_OFFS;
	cfg_tilemap_base = TILEMAP_OFFS;
	cfg_log_tileset_width = 0;
	cfg_tile_size = 0;
	cfg_pixel_mode = 0;
	cfg_transparency = 0;
	out_rdy = 0;

	for (i = 0; i < MEM_SIZE_BYTES; i = i + 1)
		mem[i] = 8'h0;

	#(10 * CLK_PERIOD);

	rst_n = 1;
	#CLK_PERIOD;
	@ (posedge clk);
	flush <= 1'b1;
	@ (posedge clk);
	flush <= 1'b0;
	out_rdy <= 1'b1;

	@ (posedge clk);

	if (bus_vld || out_vld) begin
		$display("Should be no bus requests or output pixels while disabled");
		$finish;
	end

	// Smoke test!

	en <= 1;
	cfg_log_tileset_width <= 6;
	cfg_log_w <= 6;
	cfg_log_h <= 6;
	cfg_scroll_x <= 0;
	cfg_scroll_y <= 0;

	for (i = 0; i < 256; i = i + 1)
		mem[TILEMAP_OFFS + i] <= i;

	for (i = 0; i < 64 * 64; i = i + 1) begin
		mem[TILESET_OFFS + 2 * i] <= i & 8'hff;
		mem[TILESET_OFFS + 2 * i + 1] <= i >> 8;
	end

	@ (posedge clk);

	for (i = 0; i < 64; i = i + 1) begin // FIXME just a single scanline for now (need flush!)
		while (!out_vld)
			@ (posedge clk);
		if (out_pixdata != i) begin
			$display("Output data mismatch");
			$finish;
		end
		@ (posedge clk);
	end

	$display("Test PASSED.");
	$finish;
end

endmodule
