module apb_splitter #(
	parameter W_ADDR = 16,
	parameter W_DATA = 32,
	parameter N_SLAVES = 2,
	parameter ADDR_MAP =  32'h0000_4000,
	parameter ADDR_MASK = 32'hc000_c000
) (
	input wire  [W_ADDR-1:0]          apbs_paddr,
	input wire                        apbs_psel,
	input wire                        apbs_penable,
	input wire                        apbs_pwrite,
	input wire  [W_DATA-1:0]          apbs_pwdata,
	output wire                       apbs_pready,
	output wire [W_DATA-1:0]          apbs_prdata,
	output wire                       apbs_pslverr,

	output wire [N_SLAVES*W_ADDR-1:0] apbm_paddr,
	output wire [N_SLAVES-1:0]        apbm_psel,
	output wire [N_SLAVES-1:0]        apbm_penable,
	output wire [N_SLAVES-1:0]        apbm_pwrite,
	output wire [N_SLAVES*W_DATA-1:0] apbm_pwdata,
	input wire  [N_SLAVES-1:0]        apbm_pready,
	input wire  [N_SLAVES*W_DATA-1:0] apbm_prdata,
	input wire  [N_SLAVES-1:0]        apbm_pslverr 
);

integer i;

reg [N_SLAVES-1:0] slave_mask;

always @ (*) begin
	for (i = 0; i < N_SLAVES; i = i + 1) begin
		slave_mask[i] = (apbs_paddr & ADDR_MASK[i * W_ADDR +: W_ADDR])
			== ADDR_MAP[i * W_ADDR +: W_ADDR];
	end
end

assign apbs_pready = !slave_mask || slave_mask & apbm_pready;
assign apbs_pslverr = !slave_mask || slave_mask & apbm_pslverr;

assign apbm_paddr = {N_SLAVES{apbs_paddr}};
assign apbm_psel = slave_mask & {N_SLAVES{apbs_psel}};
assign apbm_penable = slave_mask & {N_SLAVES{apbs_penable}};
assign apbm_pwrite = slave_mask & {N_SLAVES{apbs_pwrite}};
assign apbm_pwdata = {N_SLAVES{apbs_pwdata}};

onehot_mux #(
	.N_INPUTS(N_SLAVES),
	.W_INPUT(W_DATA)
) prdata_mux (
	.in(apbm_prdata),
	.sel(slave_mask),
	.out(apbs_prdata)
);

endmodule
