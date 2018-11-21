module behav_uart_rx #(
	parameter BAUD_RATE = 115200.0,
	parameter BUF_SIZE = 256
) (
	input wire rx
);

localparam BIT_PERIOD = 1_000_000_000.0 / BAUD_RATE;

reg [8*BUF_SIZE-1:0] print_buf;
reg [7:0] byte_buf;
integer print_ptr;
integer i;

initial begin
	print_buf = 0;
	print_ptr = 0;
	while (1'b1) begin
		@ (negedge rx);
		#(1.5 * BIT_PERIOD);
		for (i = 0; i < 8; i = i + 1) begin
			byte_buf = {rx, byte_buf[7:1]};
			#(BIT_PERIOD);
		end
		if (byte_buf == "\n") begin
			$display("UART: %s", print_buf);
			print_buf = 0;
			print_ptr = 0;
		end else begin
			print_buf[print_ptr * 8 +: 8] = byte_buf;
			print_ptr = print_ptr + 1;
		end
	end
end

endmodule