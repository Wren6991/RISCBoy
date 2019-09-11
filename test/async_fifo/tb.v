module tb;

// ----------------------------------------------------------------------------
// DUT instantiation

localparam W_DATA = 16;
localparam W_ADDR = 3;
localparam SYNC_STAGES = 2;

reg               wrst_n;
reg               wclk;
reg  [W_DATA-1:0] wdata;
reg               wpush;
wire              wfull;
wire              wempty;
wire [W_ADDR:0]   wlevel;

reg               rrst_n;
reg               rclk;
wire [W_DATA-1:0] rdata;
reg               rpop;
wire              rfull;
wire              rempty;
wire [W_ADDR:0]   rlevel;

async_fifo #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.SYNC_STAGES(SYNC_STAGES)
) inst_async_fifo (
	.wrst_n (wrst_n),
	.wclk   (wclk),
	.wdata  (wdata),
	.wpush  (wpush),
	.wfull  (wfull),
	.wempty (wempty),
	.wlevel (wlevel),
	.rrst_n (rrst_n),
	.rclk   (rclk),
	.rdata  (rdata),
	.rpop   (rpop),
	.rfull  (rfull),
	.rempty (rempty),
	.rlevel (rlevel)
);

// ----------------------------------------------------------------------------
// Stimulus

real clkperiod_w = 10.0;
real clkperiod_r = 10.0;
real clkdiv;
always #(0.5 * clkperiod_w) wclk = !wclk;
always #(0.5 * clkperiod_r) rclk = !rclk;

localparam FIFO_DEPTH = 1 << W_ADDR;
localparam [W_DATA-1:0] DATA_MASK = {W_DATA{1'b1}};
localparam N_TESTS = 10;

integer wctr = 0;
integer rctr = 0;
integer test_num;

initial begin
	wrst_n = 0;
	wclk = 0;
	wdata = 0;
	wpush = 0;
	rrst_n = 0;
	rclk = 0;
	rpop = 0;

	#(3 * clkperiod_w);
	#(3 * clkperiod_r);
	wrst_n <= 1'b1;
	rrst_n <= 1'b1;

	@ (posedge wclk);
	@ (posedge rclk);
	@ (posedge wclk);
	@ (posedge rclk);

	// DUT is ready now. Repeat two simple tests:
	// - Empty->full->empty
	// - Random traffic
	// ...multiple times, while randomly sweeping the two clocks.

	for (test_num = 0; test_num < N_TESTS; test_num = test_num + 1) begin
		$display($time, " Begin test %d", test_num, ", clkperiod_w: ", clkperiod_w, ", clkperiod_r: ", clkperiod_r);

		$display($time, " Empty->full->empty");
		fork
			begin: write_proc_efe
				integer i;
				@ (posedge wclk);
				// First we fill it all the way up and check it is momentarily full
				// The other side will drain it once filled
				$display($time, " W: filling");
				wpush <= 1'b1;
				for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
					wdata <= wctr;
					wctr <= wctr + 1;
					@ (posedge wclk);
				end
				wpush <= 1'b0;
				@ (posedge wclk);
				if (!wfull) begin
					$display($time, " W: FIFO should be full");
					$finish(2);
				end
				$display($time, " W: waiting for drain");
				while (!wempty)
					@ (posedge wclk);
				$display($time, " W: ok");
			end

			begin: read_proc_efe
				integer i;
				@ (posedge rclk);
				// Wait til completely full, then drain and check contents
				$display($time, " R: waiting for full");
				while (!rfull)
					@ (posedge rclk);
				$display($time, " R: draining");
				rpop <= 1'b1;
				for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
					@ (negedge rclk);
					if (rdata != (rctr & DATA_MASK)) begin
						$display($time, " R: Data mismatch");
						$finish(2);
					end
					rctr <= rctr + 1;
					@ (posedge rclk);
				end
				rpop <= 1'b0;
				$display($time, " R: ok");
			end
		join

		$display($time, " Random traffic");
		fork
			begin: write_proc_traffic
				integer i;
				@ (negedge wclk);
				for (i = 0; i < FIFO_DEPTH * 10 + 1; i = i + 1) begin
					while (wfull)
						@ (negedge wclk);
					wpush <= 1'b1;
					wdata <= wctr;
					wctr <= wctr + 1;
					@ (negedge wclk);
					wpush <= 1'b0;
					while ($random % 3)
						@ (negedge wclk);
				end
				$display($time, " W: ok");
			end

			begin: read_proc_traffic
				integer i;
				@ (negedge rclk);
				for (i = 0; i < FIFO_DEPTH * 10 + 1; i = i + 1) begin
					while (rempty)
						@ (negedge rclk);
					if (rdata != (rctr & DATA_MASK)) begin
						$display($time, " R: Data mismatch");
						$finish(2);
					end
					rpop <= 1'b1;
					rctr <= rctr + 1;
					@ (negedge rclk);
					rpop <= 1'b0;
					while ($random % 3)
						@ (negedge rclk);
				end
				$display($time, " R: ok");
			end
		join
		clkperiod_w = $unsigned($random) % 100 + 1;
		clkperiod_r = $unsigned($random) % 100 + 1;
	end
	$display("Test PASSED.");
	$finish;
end

endmodule
