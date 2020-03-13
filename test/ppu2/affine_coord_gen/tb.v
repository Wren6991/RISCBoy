module tb;

localparam CLK_PERIOD = 10.0;

localparam W_COORD_INT = 10;
localparam W_COORD_FRAC = 8;
localparam W_BUS_DATA = 32;
localparam W_COORD_FULL = W_COORD_INT + W_COORD_FRAC;

reg                    clk;
reg                    rst_n;

reg                    start_affine;
reg                    start_simple;
reg  [W_COORD_INT-1:0] raster_offs_x;
reg  [W_COORD_INT-1:0] raster_offs_y;

reg  [W_BUS_DATA-1:0]  aparam_data;
reg                    aparam_vld;
wire                   aparam_rdy;

wire [W_COORD_INT-1:0] out_u;
wire [W_COORD_INT-1:0] out_v;
wire                   out_vld;
reg                    out_rdy;

riscboy_ppu_affine_coord_gen #(
	.W_COORD_INT  (W_COORD_INT),
	.W_COORD_FRAC (W_COORD_FRAC),
	.W_BUS_DATA   (W_BUS_DATA)
) inst_riscboy_ppu_affine_coord_gen (
	.clk           (clk),
	.rst_n         (rst_n),
	.start_affine  (start_affine),
	.start_simple  (start_simple),
	.raster_offs_x (raster_offs_x),
	.raster_offs_y (raster_offs_y),
	.aparam_data   (aparam_data),
	.aparam_vld    (aparam_vld),
	.aparam_rdy    (aparam_rdy),
	.out_u         (out_u),
	.out_v         (out_v),
	.out_vld       (out_vld),
	.out_rdy       (out_rdy)
);

task test_simple_stream;
	input [W_COORD_INT-1:0] init_x;
	input [W_COORD_INT-1:0] init_y;
begin
	$display("Simple, initial coords %d, %d", init_x, init_y);
	raster_offs_x <= init_x;
	raster_offs_y <= init_y;
	start_simple <= 1'b1;
	out_rdy <= 1'b1;
	@ (posedge clk);

	raster_offs_x <= 0;
	raster_offs_y <= 0;
	start_simple <= 1'b0;
	@ (posedge clk);

	if (!out_vld) begin
		$display("Simple stream should be valid immediately");
		$finish;
	end
	if (out_u != init_x || out_v != init_y) begin
		$display("Simple stream out mismatch on first output");
		$finish;
	end
	out_rdy <= 1'b0;
	@ (posedge clk);
	@ (posedge clk);
	@ (posedge clk);
	out_rdy <= 1'b1;
	@ (posedge clk);
	if (out_u != {init_x + 1'b1} || out_v != init_y) begin
		$display("Simple stream out mismatch on second output");
		$finish;
	end
	@ (posedge clk);
	if (out_u != {init_x + 2'h2} || out_v != init_y) begin
		$display("Simple stream out mismatch on third output");
		$finish;
	end
end
endtask

task test_affine_stream;
	input [W_COORD_INT-1:0] init_x;
	input [W_COORD_INT-1:0] init_y;
	input [W_BUS_DATA-1:0]  aparam0;
	input [W_BUS_DATA-1:0]  aparam1;
	input [W_BUS_DATA-1:0]  aparam2;

	input [W_COORD_INT-1:0] expect_u0;
	input [W_COORD_INT-1:0] expect_v0;
	input [W_COORD_INT-1:0] expect_u1;
	input [W_COORD_INT-1:0] expect_v1;
	input [W_COORD_INT-1:0] expect_u2;
	input [W_COORD_INT-1:0] expect_v2;
begin
	$display("Affine, initial coords %d, %d, affine params %08h %08h %08h", init_x, init_y, aparam0, aparam1, aparam2);
	raster_offs_x <= init_x;
	raster_offs_y <= init_y;
	start_affine <= 1;
	aparam_vld <= 0;
	out_rdy <= 1;
	@ (posedge clk);

	raster_offs_x <= 0;
	raster_offs_y <= 0;
	start_affine <= 1'b0;
	@ (posedge clk);
	@ (posedge clk);
	@ (posedge clk);
	aparam_data <= aparam0;
	aparam_vld <= 1;
	@ (posedge clk);
	aparam_data <= aparam1;
	@ (posedge clk);
	aparam_vld <= 0;
	@ (posedge clk);
	@ (posedge clk);
	aparam_data <= aparam2;
	aparam_vld <= 1;
	@ (posedge clk);
	aparam_vld <= 0;
	aparam_data <= 0;
	@ (posedge clk);

	while (!out_vld)
		@ (posedge clk);
	if (out_u != expect_u0 || out_v != expect_v0) begin
		$display("Affine stream mismatch on first output");
		$finish;
	end
	@ (posedge clk);
	if (!out_vld) begin
		$display("Second coord should be ready immediately after first");
		$finish;
	end
	if (out_u != expect_u1 || out_v != expect_v1) begin
		$display("Affine stream mismatch on second output");
		$finish;
	end
	out_rdy <= 0;
	@ (posedge clk);
	@ (posedge clk);
	@ (posedge clk);
	@ (posedge clk);
	if (out_u != expect_u2 || out_v != expect_v2) begin
		$display("Affine stream mismatch on third output");
		$finish;
	end
end
endtask

// ----------------------------------------------------------------------------

always #(0.5 * CLK_PERIOD) clk = !clk;
initial begin
	clk = 0;
	rst_n = 0;
	start_affine = 0;
	start_simple = 0;
	raster_offs_x = 0;
	raster_offs_y = 0;
	aparam_data = 0;
	aparam_vld = 0;
	out_rdy = 0;
	#(5 * CLK_PERIOD);
	rst_n = 1;
	#(5 * CLK_PERIOD);
	@ (posedge clk);

	test_simple_stream(0, 0);
	test_simple_stream(1, 0);
	test_simple_stream(0, 1);
	test_simple_stream(1, 1);
	test_simple_stream({W_COORD_INT{1'b1}}, {W_COORD_INT{1'b1}});
	// Check ability to cancel stream by starting another one.
	@ (posedge clk);
	start_affine <= 1;
	@ (posedge clk);
	start_affine <= 0;
	@ (posedge clk);
	test_simple_stream(123, 456);

	// Start with a warmup!
	test_affine_stream(
		0, 0,          // initial x, y
		32'h0000_0000, // b vector
		32'h0000_0100, // A matrix (note it looks horizontally reflected here)
		32'h0100_0000,
		0, 0, // first expected coords
		1, 0, // second expected coords
		2, 0  // third expected coords
	);

	// Move initial pos
	test_affine_stream(
		5, 6,
		32'h0000_0000,
		32'h0000_0100,
		32'h0100_0000,
		5, 6,
		6, 6,
		7, 6 
	);

	// Same but with b vector
	test_affine_stream(
		5, 6,
		32'h0300_0200,
		32'h0000_0100,
		32'h0100_0000,
		5 + 8, 6 + 12,
		6 + 8, 6 + 12,
		7 + 8, 6 + 12 
	);

	// Flip A matrix
	test_affine_stream(
		5, 6,
		32'h0300_0200,
		32'h0100_0000,
		32'h0000_0100,
		6 + 8, 5 + 12,
		6 + 8, 6 + 12,
		6 + 8, 7 + 12 
	);

	// Try negative A params
	test_affine_stream(
		5, 6,
		32'h0300_0200,
		32'h0000_ff00,
		32'hff00_0000,
		-5 + 8, -6 + 12,
		-6 + 8, -6 + 12,
		-7 + 8, -6 + 12 
	);

	// Scale >1
	test_affine_stream(
		5, 6,
		32'h0000_0000,
		32'h0000_0500,
		32'h0500_0000,
		25, 30,
		30, 30,
		35, 30 
	);

	// Scale <1
	test_affine_stream(
		5, 6,
		32'h0000_0000,
		32'h0000_0080,
		32'h0080_0000,
		2, 3,
		3, 3,
		3, 3 
	);

	// As above, but set fractional bits on b component
	test_affine_stream(
		5, 7,
		32'h0000_0020,
		32'h0000_0080,
		32'h0080_0000,
		3, 3,
		3, 3,
		4, 3 
	);
	test_affine_stream(
		5, 7,
		32'h0020_0000,
		32'h0000_0080,
		32'h0080_0000,
		2, 4,
		3, 4,
		3, 4 
	);

	// Large initial value
	test_affine_stream(
		1023, 1023,
		32'h0000_0000,
		32'h0000_0100,
		32'h0100_0000,
		1023, 1023,
		0   , 1023,
		1   , 1023 
	);

	// Large initial value, negative scale
	test_affine_stream(
		1023, 1023,
		32'h0000_0000,
		32'h0000_ff00,
		32'hff00_0000,
		1   , 1,
		0   , 1,
		1023, 1 
	);

	// Try one with both u and v advancing (a shear matrix in this case!)
	test_affine_stream(
		6, 5,
		32'h0000_0000,
		32'h0000_3200,
		32'h3200_1900,
		300, 400,
		350, 425,
		400, 450
	);

	$display("Test PASSED.");
	$finish;
end

endmodule
