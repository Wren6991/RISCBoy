module tb();

localparam CLK_PERIOD = 10.0;

localparam W_DATA = 32;
localparam W_ADDR = 32;
localparam SRAM_SIZE_BYTES = 1 << 16;
localparam SRAM_DEPTH = SRAM_SIZE_BYTES * 8 / W_DATA;

reg                       clk;
reg                       rst_n;

wire                      hready;
wire                      hresp;
wire [W_ADDR-1:0]         haddr;
wire                      hwrite;
wire [1:0]                htrans;
wire [2:0]                hsize;
wire [2:0]                hburst;
wire [3:0]                hprot;
wire                      hmastlock;
wire [W_DATA-1:0]         hwdata;
wire [W_DATA-1:0]         hrdata;

reg [7:0] init_mem [0:SRAM_SIZE_BYTES-1];

revive_cpu #(
	.RESET_VECTOR(32'h0000_0000)
) cpu0 (
	.clk(clk),
	.rst_n(rst_n),

	.abhlm_hready    (hready),
	.ahblm_hresp     (hresp),
	.ahblm_haddr     (haddr),
	.ahblm_hwrite    (hwrite),
	.ahblm_htrans    (htrans),
	.ahblm_hsize     (hsize),
	.ahblm_hburst    (hburst),
	.ahblm_hprot     (hprot),
	.ahblm_hmastlock (hmastlock),
	.ahblm_hwdata    (hwdata),
	.ahblm_hrdata    (hrdata)
);

ahb_sync_sram #(
	.W_DATA(32),
	.W_ADDR(32),
	.DEPTH(SRAM_SIZE_BYTES / 4)
) sram0 (
	.clk(clk),
	.rst_n(rst_n),

	.ahbls_hready_resp (hready),
	.ahbls_hresp       (hresp),
	.ahbls_haddr       (haddr),
	.ahbls_hwrite      (hwrite),
	.ahbls_htrans      (htrans),
	.ahbls_hsize       (hsize),
	.ahbls_hburst      (hburst),
	.ahbls_hprot       (hprot),
	.ahbls_hmastlock   (hmastlock),
	.ahbls_hwdata      (hwdata),
	.ahbls_hrdata      (hrdata)
);

always #(CLK_PERIOD * 0.5) clk = !clk;

integer i;

initial begin
	clk = 1'b0;
	rst_n = 1'b0;

	// Memory initialisation is made a bit ugly by the byte-enables
	// being implemented with separate BRAM inferences, inside a generate
	for (i = 0; i < SRAM_SIZE_BYTES; i = i + 1) begin
		init_mem[i] = 8'h00;
	end
	$readmemh("../ram_init.hex", init_mem);
	$display("Loaded ram_init.hex");
	for (i = 0; i < 20; i = i + 1) begin
		$display("%h", init_mem[i]);
	end
	for (i = 0; i < SRAM_DEPTH; i = i + 1) begin
		sram0.sram.\has_byte_enable.byte_mem[0].mem [i] = init_mem[i * 4 + 0];
		sram0.sram.\has_byte_enable.byte_mem[1].mem [i] = init_mem[i * 4 + 1];
		sram0.sram.\has_byte_enable.byte_mem[2].mem [i] = init_mem[i * 4 + 2];
		sram0.sram.\has_byte_enable.byte_mem[3].mem [i] = init_mem[i * 4 + 3];
	end

	#(10 * CLK_PERIOD);
	rst_n = 1'b1;
end

endmodule