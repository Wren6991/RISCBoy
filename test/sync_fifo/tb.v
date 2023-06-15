// sync_fifo testbench
//
// A writer makes blocking writes of random data to the FIFO,
// with random delays inserted between writes.
// A reader makes blocking reads, also with random delays,
// and checks the received data.

module tb();

localparam WIDTH = 32;
localparam DEPTH = 4;
localparam W_ADDR = 2;
localparam CLK_PERIOD = 10.0;

localparam TEST_LEN = 1000;

reg clk;
reg rst_n;

reg [WIDTH-1:0]  w_data;
reg              w_en;
wire [WIDTH-1:0] r_data;
reg              r_en;

wire             full;
wire             empty;
wire [W_ADDR:0]  level;

sync_fifo #(
	.DEPTH  (DEPTH),
	.WIDTH  (WIDTH)
) uut (
	.clk    (clk),
	.rst_n  (rst_n),
	.wdata  (w_data),
	.wen    (w_en),
	.rdata  (r_data),
	.ren    (r_en),
	.flush  (1'b0),

	.full   (full),
	.empty  (empty),
	.level  (level)
);

always #(0.5 * CLK_PERIOD) clk = !clk;

reg tx_done;
reg rx_done;

reg [WIDTH-1:0] test_vec[0:TEST_LEN-1];

// Main test process

integer i;
initial begin
	clk = 1'b0;
	rst_n = 1'b0;
	tx_done = 1'b0;
	rx_done = 1'b0;

	for (i = 0; i < TEST_LEN; i = i + 1)
		test_vec[i] = $random;

	for (i = 0; i < 10; i = i + 1)
		@ (posedge clk);
	rst_n = 1'b1;

	@ (posedge tx_done);
	@ (posedge rx_done);
	$display("Test PASSED.");
	$finish;
end

// TX process;
integer tx_ptr;
initial begin
	tx_ptr = 0;
	w_en = 0;
	w_data = 0;
	@ (posedge rst_n);
	@ (negedge clk);
	while (!tx_done) begin
		while (full)
			@ (negedge clk);
		w_data = test_vec[tx_ptr];
		w_en = 1;
		@ (negedge clk);
		w_en = 0;
		while ($random % 3)
			@ (negedge clk);
		tx_ptr = tx_ptr + 1;
		if (tx_ptr == TEST_LEN)
			tx_done = 1'b1;
	end
end

// RX process
integer rx_ptr;
initial begin
	rx_ptr = 0;
	r_en = 0;
	@ (posedge rst_n);
	@ (negedge clk);
	while (!rx_done) begin
		while (empty)
			@ (negedge clk);
		if (r_data != test_vec[rx_ptr]) begin
			$display("Test FAILED: expected %h from fifo, got %h", test_vec[rx_ptr], r_data);
			$finish;
		end
		r_en = 1;
		@ (negedge clk);
		r_en = 0;
		while ($random % 3)
			@ (negedge clk);
		rx_ptr = rx_ptr + 1;
		if (rx_ptr == TEST_LEN)
			rx_done = 1'b1;
	end
end

endmodule
