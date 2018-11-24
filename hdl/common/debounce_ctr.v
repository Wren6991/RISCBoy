// i is an input which  may be glitchy.
// o tracks the state of i, but does not toggle
// until i has been stable for n cycles.

module debounce_ctr #(
	parameter N_CYCLES = 100,
	parameter W_CTR = $clog2(N_CYCLES) // let this default
) (
	input wire clk,
	input wire rst_n,
	input wire i,
	output reg o
);

reg [W_CTR-1:0] ctr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ctr <= {W_CTR{1'b0}};
		o <= 1'b0;
	end else begin
		if (o == i) begin
			ctr <= {W_CTR{1'b0}};
		end else begin
			ctr <= ctr + 1'b1;
			if (ctr == N_CYCLES - 1) begin
				o <= i;
				ctr <= {W_CTR{1'b0}};
			end
		end
	end
end

endmodule