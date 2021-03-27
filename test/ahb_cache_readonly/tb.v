module tb;

localparam W_ADDR = 32;
localparam W_DATA = 32;
localparam CACHE_DEPTH = 256;
localparam MEM_DEPTH = 2 * CACHE_DEPTH;
parameter MEM_ADDR_WIDTH = $clog2(MEM_DEPTH * W_DATA / 8);

reg                clk;
reg                rst_n;

// TB to cache
wire               src_hready_resp;
wire               src_hready = src_hready_resp;
wire               src_hresp;
reg  [W_ADDR-1:0]  src_haddr;
reg                src_hwrite;
reg  [1:0]         src_htrans;
reg  [2:0]         src_hsize;
reg  [2:0]         src_hburst;
reg  [3:0]         src_hprot;
reg                src_hmastlock;
reg  [W_DATA-1:0]  src_hwdata;
wire [W_DATA-1:0]  src_hrdata;

// ----------------------------------------------------------------------------
// Stimulus

initial clk = 1'b0;
always #5 clk = !clk;

reg enable_reads = 1'b0;

initial begin: test_seq
	integer i;

	rst_n = 0;
	src_haddr = 0;
	src_hwrite = 0;
	src_htrans = 0;
	src_hsize = 0;
	src_hburst = 0;
	src_hprot = 0;
	src_hmastlock = 0;
	src_hwdata = 0;
	@(posedge clk);
	@(posedge clk);
	rst_n <= 1;
	@(posedge clk);
	@(posedge clk);
	enable_reads <= 1'b1;

	for (i = 0; i < 10000; i = i + 1)
		@ (posedge clk);
	$display("Test PASSED.");
	$finish;
end

// This matches the contents of the SRAM model, and is easier to probe :)
reg [W_DATA-1:0] test_vec [0:MEM_DEPTH-1];
initial $readmemh("../ram_init.hex", test_vec);

reg read_in_dphase = 1'b0;
reg [W_ADDR-1:0] addr_dphase = {W_ADDR{1'b0}};

wire [W_DATA-1:0] expected_data = test_vec[addr_dphase / (W_DATA / 8)];
wire data_should_be_valid = read_in_dphase && src_hready;
wire bad_data = data_should_be_valid && src_hrdata != expected_data;

always @ (posedge clk) if (enable_reads) begin
	if (src_hready) begin
		if ($random & 8'h80) begin
			src_htrans <= 2'b10;
			src_haddr <= $random & ~({W_ADDR{1'b1}} << MEM_ADDR_WIDTH);
		end else begin
			src_htrans <= 2'b00;
			src_haddr <= {W_ADDR{1'b0}};
		end
		read_in_dphase <= src_htrans[1];
		addr_dphase <= src_haddr;
		if (bad_data) begin
			$display("Bad data at %h, expected %h, got %h", addr_dphase, expected_data, src_hrdata);
			$finish;
		end
		if (data_should_be_valid && bad_data === 1'bx) begin
			$display("Xs in data comparison!");
			$finish;
		end
	end
end

// ----------------------------------------------------------------------------
// DUT

// Cache to downstream memory
wire               dst_hready_resp;
wire               dst_hready = dst_hready_resp;
wire               dst_hresp;
wire [W_ADDR-1:0]  dst_haddr;
wire               dst_hwrite;
wire [1:0]         dst_htrans;
wire [2:0]         dst_hsize;
wire [2:0]         dst_hburst;
wire [3:0]         dst_hprot;
wire               dst_hmastlock;
wire [W_DATA-1:0]  dst_hwdata;
wire [W_DATA-1:0]  dst_hrdata;

ahb_cache_readonly #(
	.W_ADDR (W_ADDR),
	.W_DATA (W_DATA),
	.DEPTH  (CACHE_DEPTH)
) cache (
	.clk             (clk),
	.rst_n           (rst_n),
	.src_hready_resp (src_hready_resp),
	.src_hready      (src_hready),
	.src_hresp       (src_hresp),
	.src_haddr       (src_haddr),
	.src_hwrite      (src_hwrite),
	.src_htrans      (src_htrans),
	.src_hsize       (src_hsize),
	.src_hburst      (src_hburst),
	.src_hprot       (src_hprot),
	.src_hmastlock   (src_hmastlock),
	.src_hwdata      (src_hwdata),
	.src_hrdata      (src_hrdata),
	.dst_hready_resp (dst_hready_resp),
	.dst_hready      (dst_hready),
	.dst_hresp       (dst_hresp),
	.dst_haddr       (dst_haddr),
	.dst_hwrite      (dst_hwrite),
	.dst_htrans      (dst_htrans),
	.dst_hsize       (dst_hsize),
	.dst_hburst      (dst_hburst),
	.dst_hprot       (dst_hprot),
	.dst_hmastlock   (dst_hmastlock),
	.dst_hwdata      (dst_hwdata),
	.dst_hrdata      (dst_hrdata)
);

ahb_sync_sram #(
	.W_DATA       (W_DATA),
	.W_ADDR       (W_ADDR),
	.DEPTH        (MEM_DEPTH),
	.PRELOAD_FILE ("../ram_init.hex")
) mem (
	.clk               (clk),
	.rst_n             (rst_n),
	.ahbls_hready_resp (dst_hready_resp),
	.ahbls_hready      (dst_hready),
	.ahbls_hresp       (dst_hresp),
	.ahbls_haddr       (dst_haddr),
	.ahbls_hwrite      (dst_hwrite),
	.ahbls_htrans      (dst_htrans),
	.ahbls_hsize       (dst_hsize),
	.ahbls_hburst      (dst_hburst),
	.ahbls_hprot       (dst_hprot),
	.ahbls_hmastlock   (dst_hmastlock),
	.ahbls_hwdata      (dst_hwdata),
	.ahbls_hrdata      (dst_hrdata)
);

endmodule
