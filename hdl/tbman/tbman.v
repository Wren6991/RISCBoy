module tbman #(
	parameter SIMULATION = 1
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
	output wire apbs_pslverr
);

wire [7:0]  print_o;
wire        print_wen;
wire [31:0] exit_o;
wire        exit_wen;

tbman_regs inst_tbman_regs
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
	.print__o     (print_o),
	.print__wen   (print_wen),
	.exit__o      (exit_o),
	.exit__wen    (exit_wen)
);

generate
if (SIMULATION) begin: has_tbman

	reg [0:1023] print_str = 1024'h0;
	integer print_ptr = 0;

	always @ (posedge clk) begin
		if (print_wen) begin
			if (print_o == "\n") begin
				$display("TBMAN: %s", print_str);
				print_str = 1024'h0;
				print_ptr = 0;
			end else begin
				print_str[print_ptr * 8 +: 8] = print_o;
				print_ptr = print_ptr + 1;
			end
		end
		if (exit_wen) begin
			$display("TBMAN: CPU requested termination, exit code %d", exit_o);
			$finish;
		end
	end

end
endgenerate
endmodule