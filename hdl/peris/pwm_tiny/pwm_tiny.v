// Basically ok for PWMing an LED, and not much else
// 8 bit integer divider
// 8 bit value
// what more do you need?

module pwm_tiny (
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

	output wire padout
);

localparam W_DIV = 8;
localparam W_CTR = 8;

wire [W_DIV-1:0] div;
wire [W_CTR-1:0] pwm_val;
wire en;
wire inv;

reg  [W_DIV-1:0] ctr_div;
reg  [W_CTR-1:0] ctr_pwm;
reg              pwm_out;

assign padout = pwm_out ^ inv;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ctr_div <= 1'b1 | {W_DIV{1'b0}};
		ctr_pwm <= {W_CTR{1'b0}};
		pwm_out <= 1'b0;
	end else if (!en) begin
		ctr_div <= 1'b1 | {W_DIV{1'b0}};
		ctr_pwm <= pwm_val;
		pwm_out <= 1'b0;
	end else begin
		ctr_div <= ctr_div - 1'b1;
		if (ctr_div == 1) begin
			ctr_div <= div;
			ctr_pwm <= ctr_pwm - 1'b1;
			if (ctr_pwm == pwm_val)
				pwm_out <= 1'b1;
			if (!ctr_pwm)
				pwm_out <= 1'b0;
		end
	end
end

pwm_tiny_regs inst_pwm_regs (
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
	.ctrl_val_o   (pwm_val),
	.ctrl_div_o   (div),
	.ctrl_en_o    (en)
);

endmodule
