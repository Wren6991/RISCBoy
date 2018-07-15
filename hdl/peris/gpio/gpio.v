// GPIO module for FPGABoy
// APB master can bitbash, and control muxing of peripheral onto pad.

module gpio #(
	parameter N_PADS = 16
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

	inout wire [N_PADS-1:0] pads,

	// Peripheral signals

	input wire uart_tx,
	output wire uart_rx
);

localparam W_FSEL = 1;
localparam N_FSELS = 1 << W_FSEL;

wire [W_FSEL-1:0] fsel [0:N_PADS-1];

reg [N_PADS-1:0] padout;
reg [N_PADS-1:0] padoe;
reg [N_PADS-1:0] pads_r;
assign pads = pads_r;

integer i;

always @ (*) begin
	for (i = 0; i < N_PADS; i = i + 1) begin
		if (proc_oe[i]) begin
			pads_r[i] = 1'bz;
		end else begin
			pads_r[i] = proc_out[i];
		end
	end
end

// Output muxing

wire [N_PADS-1:0] proc_out;
wire [N_PADS-1:0] proc_oe;
wire [N_FSELS-1:0] padout_all [0:N_PADS-1];
wire [N_FSELS-1:0] padoe_all [0:N_PADS-1];

assign padout_all[0 ] = {proc_out[0 ]        , 1'b0                };
assign padout_all[1 ] = {proc_out[1 ]        , 1'b0                };
assign padout_all[2 ] = {proc_out[2 ]        , 1'b0                };
assign padout_all[3 ] = {proc_out[3 ]        , 1'b0                };
assign padout_all[4 ] = {proc_out[4 ]        , 1'b0                };
assign padout_all[5 ] = {proc_out[5 ]        , 1'b0                };
assign padout_all[6 ] = {proc_out[6 ]        , 1'b0                };
assign padout_all[7 ] = {proc_out[7 ]        , 1'b0                };
assign padout_all[8 ] = {proc_out[8 ]        , 1'b0                };
assign padout_all[9 ] = {proc_out[9 ]        , 1'b0                };
assign padout_all[10] = {proc_out[10]        , 1'b0                };
assign padout_all[11] = {proc_out[11]        , 1'b0                };
assign padout_all[12] = {proc_out[12]        , 1'b0                };
assign padout_all[13] = {proc_out[13]        , 1'b0                };
assign padout_all[14] = {proc_out[14]        , 1'b0                };
assign padout_all[15] = {proc_out[15]        , uart_tx             };

assign padoe_all[0 ]  = {proc_oe[0 ]         , 1'b0                };
assign padoe_all[1 ]  = {proc_oe[1 ]         , 1'b0                };
assign padoe_all[2 ]  = {proc_oe[2 ]         , 1'b0                };
assign padoe_all[3 ]  = {proc_oe[3 ]         , 1'b0                };
assign padoe_all[4 ]  = {proc_oe[4 ]         , 1'b0                };
assign padoe_all[5 ]  = {proc_oe[5 ]         , 1'b0                };
assign padoe_all[6 ]  = {proc_oe[6 ]         , 1'b0                };
assign padoe_all[7 ]  = {proc_oe[7 ]         , 1'b0                };
assign padoe_all[8 ]  = {proc_oe[8 ]         , 1'b0                };
assign padoe_all[9 ]  = {proc_oe[9 ]         , 1'b0                };
assign padoe_all[10]  = {proc_oe[10]         , 1'b0                };
assign padoe_all[11]  = {proc_oe[11]         , 1'b0                };
assign padoe_all[12]  = {proc_oe[12]         , 1'b0                };
assign padoe_all[13]  = {proc_oe[13]         , 1'b0                };
assign padoe_all[14]  = {proc_oe[14]         , 1'b0                };
assign padoe_all[15]  = {proc_oe[15]         , 1'b1                };

always @ (*) begin: gpio_mux
	integer i;
	for (i = 0; i < N_PADS; i = i + 1) begin
		padout[i] = padout_all[i][fsel[i]];
		padoe[i] = padoe_all[i][fsel[i]];
	end
end

// Input assignments (TODO: multi-source input muxing)

assign uart_rx = pads[14];

// APB Regblock

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
	.out_o        (proc_out),
	.dir_o        (proc_oe),
	.in_i         (pads),
	.fsel0_p0_o      (fsel[0 ]),
	.fsel0_p2_o      (fsel[2 ]),
	.fsel0_p3_o      (fsel[3 ]),
	.fsel0_p4_o      (fsel[4 ]),
	.fsel0_p5_o      (fsel[5 ]),
	.fsel0_p6_o      (fsel[6 ]),
	.fsel0_p7_o      (fsel[7 ]),
	.fsel0_p8_o      (fsel[8 ]),
	.fsel0_p9_o      (fsel[9 ]),
	.fsel0_p10_o     (fsel[10]),
	.fsel0_p11_o     (fsel[11]),
	.fsel0_p12_o     (fsel[12]),
	.fsel0_p13_o     (fsel[13]),
	.fsel0_p14_o     (fsel[14]),
	.fsel0_p15_o     (fsel[15])
);

endmodule