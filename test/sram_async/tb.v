module tb();

localparam WIDTH = 16;
localparam DEPTH = 1 << 18;
localparam W_ADDR = $clog2(DEPTH)

reg [W_ADDR-1:0] addr;
reg [WIDTH-1:0] dq;
reg ce_n;
reg we_n;
reg oe_n;
reg ub_n;
reg lb_n;

sram_async #(
	.WIDTH(WIDTH),
	.DEPTH(DEPTH),
	.W_ADDR(W_ADDR)
) uut (
	.addr (addr),
	.dq   (dq),
	.ce_n (ce_n),
	.we_n (we_n),
	.oe_n (oe_n),
	.ub_n (ub_n),
	.lb_n (lb_n)
);

initial begin
	ce_n = 0;
	we_n = 1;
	oe_n = 1;
	ub_n = 1;
	lb_n = 1;
end

endmodule