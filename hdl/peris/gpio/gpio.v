module gpio #(
	parameter N_PADS = 11
) (
	input wire clk,
	input wire rst_n,
	
	// APB Port
	input wire apbs_psel,
	input wire apbs_penable,
	input wire apbs_pwrite,
	input wire [15:0] apbs_paddr,
	input wire [31:0] apbs_pwdata,
	output wire [31:0] apbs_prdata,
	output wire apbs_pready,
	output wire apbs_pslverr,

	output reg [N_PADS-1:0] padout,
	output reg [N_PADS-1:0] padoe,
	input wire [N_PADS-1:0] padin,
);

`include "gpio_pinmap.vh"

wire rst_n_sync;

reset_sync #(
	.N_CYCLES (2)
) inst_reset_sync (
	.clk       (clk),
	.rst_n_in  (rst_n),
	.rst_n_out (rst_n_sync)
);

// Register inputs before sending to processor

reg [N_PADS-1:0] padin_reg;

always @ (posedge clk or negedge rst_n_sync) begin
	if (!rst_n_sync) begin
		padin_reg <= {N_PADS{1'b0}};
	end else begin
		padin_reg <= padin;
	end
end

// APB Regblock

gpio_regs inst_gpio_regs
(
	.clk           (clk),
	.rst_n         (rst_n_sync),
	.apbs_psel     (apbs_psel),
	.apbs_penable  (apbs_penable),
	.apbs_pwrite   (apbs_pwrite),
	.apbs_paddr    (apbs_paddr),
	.apbs_pwdata   (apbs_pwdata),
	.apbs_prdata   (apbs_prdata),
	.apbs_pready   (apbs_pready),
	.apbs_pslverr  (apbs_pslverr),
	.out_o         (padout),
	.dir_o         (padoe),
	.in_i          (padin_reg)
);

endmodule
