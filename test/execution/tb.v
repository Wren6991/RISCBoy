module tb();

localparam CLK_PERIOD = 10.0;

localparam W_DATA = 32;
localparam W_ADDR = 32;
localparam SRAM_SIZE_BYTES = 1 << 20;
localparam SRAM_DEPTH = SRAM_SIZE_BYTES * 8 / W_DATA;

reg                       clk;
reg                       rst_n;

wire                      cpu_hready;
wire                      cpu_hresp;
wire [W_ADDR-1:0]         cpu_haddr;
wire                      cpu_hwrite;
wire [1:0]                cpu_htrans;
wire [2:0]                cpu_hsize;
wire [2:0]                cpu_hburst;
wire [3:0]                cpu_hprot;
wire                      cpu_hmastlock;
wire [W_DATA-1:0]         cpu_hwdata;
wire [W_DATA-1:0]         cpu_hrdata;

wire                      trafficgen_hready;
wire                      trafficgen_hresp;
wire [W_ADDR-1:0]         trafficgen_haddr;
wire                      trafficgen_hwrite;
wire [1:0]                trafficgen_htrans;
wire [2:0]                trafficgen_hsize;
wire [2:0]                trafficgen_hburst;
wire [3:0]                trafficgen_hprot;
wire                      trafficgen_hmastlock;
wire [W_DATA-1:0]         trafficgen_hwdata;
wire [W_DATA-1:0]         trafficgen_hrdata;

wire                      sram_hready;
wire                      sram_hresp;
wire [W_ADDR-1:0]         sram_haddr;
wire                      sram_hwrite;
wire [1:0]                sram_htrans;
wire [2:0]                sram_hsize;
wire [2:0]                sram_hburst;
wire [3:0]                sram_hprot;
wire                      sram_hmastlock;
wire [W_DATA-1:0]         sram_hwdata;
wire [W_DATA-1:0]         sram_hrdata;

hazard5_cpu #(
	.RESET_VECTOR(32'h0000_0000)
) cpu0 (
	.clk             (clk),
	.rst_n           (rst_n),

	.ahblm_hready    (cpu_hready),
	.ahblm_hresp     (cpu_hresp),
	.ahblm_haddr     (cpu_haddr),
	.ahblm_hwrite    (cpu_hwrite),
	.ahblm_htrans    (cpu_htrans),
	.ahblm_hsize     (cpu_hsize),
	.ahblm_hburst    (cpu_hburst),
	.ahblm_hprot     (cpu_hprot),
	.ahblm_hmastlock (cpu_hmastlock),
	.ahblm_hwdata    (cpu_hwdata),
	.ahblm_hrdata    (cpu_hrdata)
);

trafficgen #(
	.W_ADDR (W_ADDR),
	.W_DATA (W_DATA),
	.TARGET_ADDR (0),
	.IDLENESS (2)
) trafficgen0 (
	.clk             (clk),
	.rst_n           (rst_n),

	.ahblm_hready    (trafficgen_hready),
	.ahblm_hresp     (trafficgen_hresp),
	.ahblm_haddr     (trafficgen_haddr),
	.ahblm_hwrite    (trafficgen_hwrite),
	.ahblm_htrans    (trafficgen_htrans),
	.ahblm_hsize     (trafficgen_hsize),
	.ahblm_hburst    (trafficgen_hburst),
	.ahblm_hprot     (trafficgen_hprot),
	.ahblm_hmastlock (trafficgen_hmastlock),
	.ahblm_hwdata    (trafficgen_hwdata),
	.ahblm_hrdata    (trafficgen_hrdata)
);

ahbl_arbiter #(
		.N_PORTS(2),
		.W_ADDR(W_ADDR),
		.W_DATA(W_DATA)
	) arbiter0 (
	.clk             (clk),
	.rst_n           (rst_n),
	.src_hready      ({cpu_hready    , trafficgen_hready   }), // trafficgen has higher priority (since its purpose is to generate stall signals!
	.src_hready_resp ({cpu_hready    , trafficgen_hready   }),
	.src_hresp       ({cpu_hresp     , trafficgen_hresp    }),
	.src_haddr       ({cpu_haddr     , trafficgen_haddr    }),
	.src_hwrite      ({cpu_hwrite    , trafficgen_hwrite   }),
	.src_htrans      ({cpu_htrans    , trafficgen_htrans   }),
	.src_hsize       ({cpu_hsize     , trafficgen_hsize    }),
	.src_hburst      ({cpu_hburst    , trafficgen_hburst   }),
	.src_hprot       ({cpu_hprot     , trafficgen_hprot    }),
	.src_hmastlock   ({cpu_hmastlock , trafficgen_hmastlock}),
	.src_hwdata      ({cpu_hwdata    , trafficgen_hwdata   }),
	.src_hrdata      ({cpu_hrdata    , trafficgen_hrdata   }),
	.dst_hready      ( /**/ ),
	.dst_hready_resp (sram_hready),
	.dst_hresp       (sram_hresp),
	.dst_haddr       (sram_haddr),
	.dst_hwrite      (sram_hwrite),
	.dst_htrans      (sram_htrans),
	.dst_hsize       (sram_hsize),
	.dst_hburst      (sram_hburst),
	.dst_hprot       (sram_hprot),
	.dst_hmastlock   (sram_hmastlock),
	.dst_hwdata      (sram_hwdata),
	.dst_hrdata      (sram_hrdata)
);


ahb_sync_sram #(
	.W_DATA(32),
	.W_ADDR(32),
	.DEPTH(SRAM_SIZE_BYTES / 4),
	.PRELOAD_FILE("../ram_init32.hex")
) sram0 (
	.clk(clk),
	.rst_n(rst_n),

	.ahbls_hready_resp (sram_hready),
	.ahbls_hresp       (sram_hresp),
	.ahbls_haddr       (sram_haddr),
	.ahbls_hwrite      (sram_hwrite),
	.ahbls_htrans      (sram_htrans),
	.ahbls_hsize       (sram_hsize),
	.ahbls_hburst      (sram_hburst),
	.ahbls_hprot       (sram_hprot),
	.ahbls_hmastlock   (sram_hmastlock),
	.ahbls_hwdata      (sram_hwdata),
	.ahbls_hrdata      (sram_hrdata)
);

always #(CLK_PERIOD * 0.5) clk = !clk;

integer i;
reg [31:0] result_ptr_mem [0:1];
reg [31:0] result_base_ptr;
reg [31:0] result_end_ptr;

initial begin
	clk = 1'b0;
	rst_n = 1'b0;

	result_ptr_mem[0] = 0;
	result_ptr_mem[1] = 0;
	$readmemh("../result_ptr.hex", result_ptr_mem);
	result_base_ptr = result_ptr_mem[0];
	result_end_ptr = result_ptr_mem[1];
	$display("Results at mem offset %h -> %h", result_base_ptr, result_end_ptr);

	$display(".testdata preload:");
	for (i = result_base_ptr; i < result_end_ptr; i = i + 4)
		$display("%h", sram0.sram.mem [i / 4]);


	#(10 * CLK_PERIOD);
	rst_n = 1'b1;

	#(5000 * CLK_PERIOD);
	
	$display("Register contents:");
	for (i = 0; i < 32; i = i + 1) begin
		$display("%h", cpu0.inst_regfile_1w2r.\real_dualport_reset.mem [i]);
	end

	$display("Test results:");
	for (i = result_base_ptr; i < result_end_ptr; i = i + 4)
		$display("%h", sram0.sram.mem [i / 4]);

	$finish(2);
end

endmodule