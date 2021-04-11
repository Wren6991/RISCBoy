module tb();

localparam CLK_PERIOD = 10.0;

localparam W_DATA = 32;
localparam W_ADDR = 32;
localparam SRAM_SIZE_BYTES = 1 << 20;
localparam SRAM_DEPTH = SRAM_SIZE_BYTES * 8 / W_DATA;

reg                       clk;
reg                       rst_n;
reg                       rst_n_proc;

wire                      i_hready = 1'b1;
wire                      i_hresp = 1'b0;
wire [W_ADDR-1:0]         i_haddr;
wire                      i_hwrite;
wire [1:0]                i_htrans;
wire [2:0]                i_hsize;
wire [2:0]                i_hburst;
wire [3:0]                i_hprot;
wire                      i_hmastlock;
wire [W_DATA-1:0]         i_hwdata;
wire [W_DATA-1:0]         i_hrdata;

wire                      d_hready = 1'b1;
wire                      d_hresp = 1'b0;
wire [W_ADDR-1:0]         d_haddr;
wire                      d_hwrite;
wire [1:0]                d_htrans;
wire [2:0]                d_hsize;
wire [2:0]                d_hburst;
wire [3:0]                d_hprot;
wire                      d_hmastlock;
wire [W_DATA-1:0]         d_hwdata;
wire [W_DATA-1:0]         d_hrdata;


hazard5_cpu_2port #(
	.RESET_VECTOR(32'h0000_0000)
) cpu0 (
	.clk             (clk),
	.rst_n           (rst_n_proc),

	.i_hready        (i_hready),
	.i_hresp         (i_hresp),
	.i_haddr         (i_haddr),
	.i_hwrite        (i_hwrite),
	.i_htrans        (i_htrans),
	.i_hsize         (i_hsize),
	.i_hburst        (i_hburst),
	.i_hprot         (i_hprot),
	.i_hmastlock     (i_hmastlock),
	.i_hwdata        (i_hwdata),
	.i_hrdata        (i_hrdata),

	.d_hready        (d_hready),
	.d_hresp         (d_hresp),
	.d_haddr         (d_haddr),
	.d_hwrite        (d_hwrite),
	.d_htrans        (d_htrans),
	.d_hsize         (d_hsize),
	.d_hburst        (d_hburst),
	.d_hprot         (d_hprot),
	.d_hmastlock     (d_hmastlock),
	.d_hwdata        (d_hwdata),
	.d_hrdata        (d_hrdata),

	.irq             (16'h0)
);

reg [31:0] sram[0:SRAM_SIZE_BYTES/4-1];
initial $readmemh("../ram_init32.hex", sram);


// Dual-ported memory model:

reg              i_active_dphase;
reg [W_ADDR-1:0] i_haddr_dphase;

reg              d_active_dphase;
reg              d_hwrite_dphase;
reg [2:0]        d_hsize_dphase;
reg [W_ADDR-1:0] d_haddr_dphase;

assign i_hrdata = i_active_dphase &&                     i_hready ? sram[i_haddr_dphase / 4] : {W_DATA{1'bx}};
assign d_hrdata = d_active_dphase && !d_hwrite_dphase && d_hready ? sram[d_haddr_dphase / 4] : {W_DATA{1'bx}};

always @ (posedge clk or negedge rst_n) begin: ram_model
	integer i;
	if (!rst_n) begin
		i_active_dphase <= 1'b0;
		i_haddr_dphase <= {W_ADDR{1'b0}};
		d_active_dphase <= 1'b0;
		d_hwrite_dphase <= 1'b0;
		d_hsize_dphase <= 3'h0;
		d_haddr_dphase <= {W_ADDR{1'b0}};
	end else begin
		if (i_hready) begin
			i_active_dphase <= i_htrans[1];
			i_haddr_dphase <= i_haddr;
		end
		if (d_hready) begin
			d_active_dphase <= d_htrans[1];
			d_hwrite_dphase <= d_hwrite;
			d_hsize_dphase <= d_hsize;
			d_haddr_dphase <= d_haddr;
		end
		if (d_active_dphase && d_hwrite_dphase) begin
			for (i = d_haddr_dphase; i < d_haddr_dphase + (1 << d_hsize_dphase); i = i + 1) begin
				sram[i / 4][i % 4 * 8 +: 8] <= d_hwdata[i % 4 * 8 +: 8];
			end
		end
	end
end

always #(CLK_PERIOD * 0.5) clk = !clk;

integer i;
reg [31:0] result_ptr_mem [0:1];
reg [31:0] result_base_ptr;
reg [31:0] result_end_ptr;

initial begin
	clk = 1'b0;
	rst_n_proc = 1'b0;
	rst_n = 1'b0;

	result_ptr_mem[0] = 0;
	result_ptr_mem[1] = 0;
	$readmemh("../result_ptr.hex", result_ptr_mem);
	result_base_ptr = result_ptr_mem[0];
	result_end_ptr = result_ptr_mem[1];
	$display("Results at mem offset %h -> %h", result_base_ptr, result_end_ptr);

	$display(".testdata preload:");
	for (i = result_base_ptr; i < result_end_ptr; i = i + 4)
		$display("%h", sram[i / 4]);


	#(10 * CLK_PERIOD);
	rst_n_proc = 1'b1;
	rst_n = 1'b1;

	#(5000 * CLK_PERIOD);
	
	$display("Register contents:");
	for (i = 0; i < 32; i = i + 1) begin
		$display("%h", cpu0.core.inst_regfile_1w2r.\real_dualport_reset.mem [i]);
	end

	// Reset the processor (+ trafficgen) and wait a couple cycles.
	// This allows a potentially-buffered write (inside controller) to be
	// committed to SRAM, so we can read it out.
	rst_n_proc = 1'b0;
	@ (posedge clk);
	@ (posedge clk);

	$display("Test results:");
	for (i = result_base_ptr; i < result_end_ptr; i = i + 4)
		$display("%h", sram[i / 4]);

	$finish(2);
end

endmodule
