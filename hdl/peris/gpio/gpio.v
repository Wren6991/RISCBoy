// GPIO module for FPGABoy
// APB master can bitbash, and control muxing of peripheral onto pad.

module gpio #(
	parameter N_PADS  = 16,
	parameter USE_BUF = 16'hffff
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

	input wire lcd_pwm,
	input wire uart_tx,
	output wire uart_rx,
	input wire spi_sclk,
	input wire spi_cs,
	input wire spi_sdo,
	output wire spi_sdi
);

localparam W_FSEL = 1;
localparam N_FSELS = 1 << W_FSEL;

wire [W_FSEL-1:0] fsel [0:N_PADS-1];

reg  [N_PADS-1:0] padout;
reg  [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

genvar g;
generate
for (g = 0; g < N_PADS; g = g + 1) begin: gen_buf
	if (USE_BUF[g]) begin: has_buf
		tristate_io padbuf (
			.out    (padout[g]),
			.out_en (padoe[g]),
			.in     (padin[g]),
			.pad    (pads[g])
		);
	end else begin: no_buf
		// On some FPGAs, different primitives are used to drive some package pins
		// e.g. RGB driver on iCE40UP.
		// Instantiating an iobuf would cause problems for these pins.
		assign pads[g] = padout[g];
		assign padin[g] = pads[g];
	end
end
endgenerate

// Output muxing

wire [N_PADS-1:0] proc_out;
wire [N_PADS-1:0] proc_oe;
wire [N_FSELS-1:0] padout_all [0:N_PADS-1];
wire [N_FSELS-1:0] padoe_all [0:N_PADS-1];

assign padout_all[0 ] = {1'b0                , proc_out[0 ]        };
assign padout_all[1 ] = {1'b0                , proc_out[1 ]        };
assign padout_all[2 ] = {1'b0                , proc_out[2 ]        };
assign padout_all[3 ] = {1'b0                , proc_out[3 ]        };
assign padout_all[4 ] = {1'b0                , proc_out[4 ]        };
assign padout_all[5 ] = {lcd_pwm             , proc_out[5 ]        };
assign padout_all[6 ] = {1'b0                , proc_out[6 ]        };
assign padout_all[7 ] = {1'b0                , proc_out[7 ]        };
assign padout_all[8 ] = {1'b0                , proc_out[8 ]        };
assign padout_all[9 ] = {1'b0                , proc_out[9 ]        };
assign padout_all[10] = {spi_cs              , proc_out[10]        };
assign padout_all[11] = {spi_sclk            , proc_out[11]        };
assign padout_all[12] = {spi_sdo             , proc_out[12]        };
assign padout_all[13] = {spi_sdi             , proc_out[13]        };
assign padout_all[14] = {1'b0                , proc_out[14]        };
assign padout_all[15] = {uart_tx             , proc_out[15]        };

assign padoe_all[0 ]  = {1'b0                , proc_oe[0 ]         };
assign padoe_all[1 ]  = {1'b0                , proc_oe[1 ]         };
assign padoe_all[2 ]  = {1'b0                , proc_oe[2 ]         };
assign padoe_all[3 ]  = {1'b0                , proc_oe[3 ]         };
assign padoe_all[4 ]  = {1'b0                , proc_oe[4 ]         };
assign padoe_all[5 ]  = {1'b1                , proc_oe[5 ]         };
assign padoe_all[6 ]  = {1'b0                , proc_oe[6 ]         };
assign padoe_all[7 ]  = {1'b0                , proc_oe[7 ]         };
assign padoe_all[8 ]  = {1'b0                , proc_oe[8 ]         };
assign padoe_all[9 ]  = {1'b0                , proc_oe[9 ]         };
assign padoe_all[10]  = {1'b1                , proc_oe[10]         };
assign padoe_all[11]  = {1'b1                , proc_oe[11]         };
assign padoe_all[12]  = {1'b1                , proc_oe[12]         };
assign padoe_all[13]  = {1'b0                , proc_oe[13]         };
assign padoe_all[14]  = {1'b0                , proc_oe[14]         };
assign padoe_all[15]  = {1'b1                , proc_oe[15]         };

always @ (*) begin: gpio_mux
	integer i;
	for (i = 0; i < N_PADS; i = i + 1) begin
		padout[i] = padout_all[i][fsel[i]];
		padoe[i] = padoe_all[i][fsel[i]];
	end
end

// Register inputs before sending to processor

reg [N_PADS-1:0] padin_reg;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		padin_reg <= {N_PADS{1'b0}};
	end else begin
		padin_reg <= padin;
	end
end

// Input assignments (TODO: multi-source input muxing)

assign uart_rx = padin_reg[14]; // UART isn't going to mind an extra clock of latency!
assign spi_sdi = padin[13];     // SPI certainly will though

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
	.in_i         (padin_reg),
	.fsel0_p0_o   (fsel[0 ]),
	.fsel0_p1_o   (fsel[1 ]),
	.fsel0_p2_o   (fsel[2 ]),
	.fsel0_p3_o   (fsel[3 ]),
	.fsel0_p4_o   (fsel[4 ]),
	.fsel0_p5_o   (fsel[5 ]),
	.fsel0_p6_o   (fsel[6 ]),
	.fsel0_p7_o   (fsel[7 ]),
	.fsel0_p8_o   (fsel[8 ]),
	.fsel0_p9_o   (fsel[9 ]),
	.fsel0_p10_o  (fsel[10]),
	.fsel0_p11_o  (fsel[11]),
	.fsel0_p12_o  (fsel[12]),
	.fsel0_p13_o  (fsel[13]),
	.fsel0_p14_o  (fsel[14]),
	.fsel0_p15_o  (fsel[15])
);

endmodule