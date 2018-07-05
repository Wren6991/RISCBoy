// Integer + fractional divider with 1st-order delta sigma pulse swallowing

module clkdiv_frac #(
	parameter W_DIV_INT = 16,
	parameter W_DIV_FRAC = 8
) (
	input wire                  clk,
	input wire                  rst_n,

	input wire                  en,
	input wire [W_DIV_INT-1:0]  div_int,
	input wire [W_DIV_FRAC-1:0] div_frac,

	output reg                  clk_en
);

reg [W_DIV_INT-1:0]  ctr_int;
reg [W_DIV_FRAC-1:0] ctr_frac;
reg                  frac_carry;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		clk_en <= 1'b0;
		ctr_int <= {W_DIV_INT{1'b0}} | 1'b1;
		ctr_frac <= {W_DIV_FRAC{1'b0}};
		frac_carry <= 1'b0;
	end else if (!en) begin
		// Keep everything clear so that we raise
		// clk_en on the cycle immediately following being enabled
		clk_en <= 1'b0;
		ctr_int <= {W_DIV_INT{1'b0}} | 1'b1;
		ctr_frac <= {W_DIV_FRAC{1'b0}};
		frac_carry <= 1'b0;
	end else begin
		if (ctr_int == 1) begin
			{frac_carry, ctr_frac} <= ctr_frac + div_frac;
			ctr_int <= div_int + frac_carry;
			clk_en <= 1'b1;
		end else begin
			clk_en <= 1'b0;
			ctr_int <= ctr_int - 1'b1;
		end
	end
end

endmodule