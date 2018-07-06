always assume(rst_n == !$initstate);
always assume(!d_invalid);

always @ (posedge clk) begin
	// Don't think about states where we're endlessly stalled
	assume(!($past(stall_cause_ahb, 1) && $past(stall_cause_ahb, 2) && $past(stall_cause_ahb, 3)));
	if ($past(flush_d_x && !stall_cause_ahb))
		assert(xm_rd == 0);
	if ($past(flush_d_x && !stall_cause_ahb, 2))
		assert(xm_rd == 0);
end