module tb();

localparam CLK_PERIOD = 20;

reg clk;
reg rst_n;

fpgaboy_core #(.SIMULATION(1)) inst_fpgaboy_core (.clk(clk), .rst_n(rst_n));

always #(CLK_PERIOD * 0.5) clk = !clk;

initial begin
	clk = 1'b0;
	rst_n = 1'b0;

	#(10 * CLK_PERIOD);
	rst_n = 1'b1;
end

endmodule