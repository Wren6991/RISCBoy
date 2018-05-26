module tb();

localparam W = 32;
localparam TEST_LEN = 10000;

reg [W-1:0] a;
reg [W-1:0] b;
wire [W*2-1:0] out;

wallace_mult #(.W(W)) inst_radix2_mult (.sext_a(1'b0), .sext_b(1'b0), .a(a), .b(b), .out(out));

integer i;

initial begin
	for (i = 0; i < TEST_LEN; i = i + 1) begin
		a = $random;
		b = $random;
		#5;
		if (out != a * b) begin
			$display("Fail: %d * %d != %d", a, b, out);
			$finish(2);
		end
		#5;
	end
	$display("Test PASSED.");
	$finish;
end

endmodule