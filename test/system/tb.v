module tb();

localparam CLK_PERIOD = 20;

localparam RAM_BASE = 32'h2000_0000;
localparam RAM_SIZE_BYTES = 1 << 18;
localparam RAM_DEPTH = RAM_SIZE_BYTES / 4;
integer i;

reg clk;
reg rst_n;

fpgaboy_core #(.SIMULATION(1)) dut (.clk(clk), .rst_n(rst_n));

always #(CLK_PERIOD * 0.5) clk = !clk;

reg [7:0] init_mem [RAM_BASE : RAM_BASE + RAM_SIZE_BYTES - 0];

initial begin
	clk = 1'b0;
	rst_n = 1'b0;

	for (i = 0; i < RAM_SIZE_BYTES; i = i + 1)
		init_mem[RAM_BASE + i] = 8'h0;
	$readmemh("../ram_init.hex", init_mem);
	for (i = 0; i < RAM_DEPTH; i = i + 1) begin
		if (i < 100)
			$display("ram: %h, %h, %h, %h", init_mem[RAM_BASE + i * 4 + 0], init_mem[RAM_BASE + i * 4 + 1], init_mem[RAM_BASE + i * 4 + 2], init_mem[RAM_BASE + i * 4 + 3]);
		dut.sram0.sram.\has_byte_enable.byte_mem[0].mem [i] = init_mem[RAM_BASE + i * 4 + 0];
		dut.sram0.sram.\has_byte_enable.byte_mem[1].mem [i] = init_mem[RAM_BASE + i * 4 + 1];
		dut.sram0.sram.\has_byte_enable.byte_mem[2].mem [i] = init_mem[RAM_BASE + i * 4 + 2];
		dut.sram0.sram.\has_byte_enable.byte_mem[3].mem [i] = init_mem[RAM_BASE + i * 4 + 3];
	end


	#(10 * CLK_PERIOD);
	rst_n = 1'b1;
end

endmodule