module gpio #(
	parameter N_PADS = 11
) (
	input  wire              clk,
	input  wire              rst_n,
	
	// APB Port
	input  wire              apbs_psel,
	input  wire              apbs_penable,
	input  wire              apbs_pwrite,
	input  wire [15:0]       apbs_paddr,
	input  wire [31:0]       apbs_pwdata,
	output wire [31:0]       apbs_prdata,
	output wire              apbs_pready,
	output wire              apbs_pslverr,

	output wire [N_PADS-1:0] padout,
	output wire [N_PADS-1:0] padoe,
	input  wire [N_PADS-1:0] padin
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

// Assign unused outputs

function output_is_unused;
	input integer out;
begin
	output_is_unused = out != PIN_LED;
end
endfunction

genvar i;
generate
for (i = 0; i < N_GPIOS; i = i + 1) begin: assign_unused_out
	if (output_is_unused(i)) begin
		assign padout[i] = 1'b0;
		assign padoe[i] = 1'b0;
	end
end
endgenerate

// APB Regblock

gpio_regs inst_gpio_regs
(
	.clk             (clk),
	.rst_n           (rst_n_sync),
	.apbs_psel       (apbs_psel),
	.apbs_penable    (apbs_penable),
	.apbs_pwrite     (apbs_pwrite),
	.apbs_paddr      (apbs_paddr),
	.apbs_pwdata     (apbs_pwdata),
	.apbs_prdata     (apbs_prdata),
	.apbs_pready     (apbs_pready),
	.apbs_pslverr    (apbs_pslverr),

	.out_led_o       (padout[PIN_LED]),
	.dir_led_o       (padoe[PIN_LED]),

	.in_led_i        (padin_reg[PIN_LED       ]),
	.in_dpad_u_i     (padin_reg[PIN_DPAD_U    ]),
	.in_dpad_d_i     (padin_reg[PIN_DPAD_D    ]),
	.in_dpad_l_i     (padin_reg[PIN_DPAD_L    ]),
	.in_dpad_r_i     (padin_reg[PIN_DPAD_R    ]),
	.in_btn_a_i      (padin_reg[PIN_BTN_A     ]),
	.in_btn_b_i      (padin_reg[PIN_BTN_B     ]),
	.in_btn_x_i      (padin_reg[PIN_BTN_X     ]),
	.in_btn_y_i      (padin_reg[PIN_BTN_Y     ]),
	.in_btn_start_i  (padin_reg[PIN_BTN_START ]),
	.in_btn_select_i (padin_reg[PIN_BTN_SELECT])
);

endmodule
