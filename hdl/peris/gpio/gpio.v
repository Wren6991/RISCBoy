module gpio #(
	parameter N_PADS = 32
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

	inout wire [N_PADS-1:0] pads
);

wire [N_PADS-1:0] out__o;
wire [N_PADS-1:0] dir__o;
reg  [N_PADS-1:0] pads_r;
assign pads = pads_r;

integer i;

always @ (*) begin
	for (i = 0; i < N_PADS; i = i + 1) begin
		if (dir__o[i]) begin
			pads_r[i] = 1'bz;
		end else begin
			pads_r[i] = out__o[i];
		end
	end
end

gpio_regs inst_gpio_regs
(
	.clk          (clk),
	.rst_n        (rst_n),
	.apbs_psel    (apbs_psel),
	.apbs_penable (apbs_penable),
	.apbs_pwrite  (apbs_pwrite),
	.apbs_paddr   (apbs_paddr),
	.apbs_pwdata  (apbs_pwdata),
	.apbs_prdata  (apbs_prdata),
	.apbs_pready  (apbs_pready),
	.apbs_pslverr (apbs_pslverr),
	.out__o       (out__o),
	.dir__o       (dir__o),
	.in__i        (pads)
);

endmodule