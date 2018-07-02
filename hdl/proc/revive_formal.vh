always assume(rst_n == !$initstate);

always @ (posedge clk) begin
	assume(!d_invalid);
end