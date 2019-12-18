module onehot_priority_dynamic #(
	parameter N_REQ = 8,
	parameter N_PRIORITIES = 2,
	parameter HIGHEST_WINS = 1, // If 1, numerically highest level has greatest priority. Otherwise, level 0 wins.
	parameter W_PRIORITY = $clog2(N_PRIORITIES) // do not modify
) (
	input wire [N_REQ*W_PRIORITY-1:0] priority,
	input wire [N_REQ-1:0]            req,
	input wire [N_REQ-1:0]            gnt
);

// The steps are:
// - Stratify requests according to their level
// - Select the highest level with active requests
// - Mask only those requests at this level
// - Do a standard priority select on those requests as a tie break

reg [N_REQ-1:0]        req_stratified [0:N_PRIORITIES-1];
reg [N_PRIORITIES-1:0] level_has_req;

always @ (*) begin: stratify
	integer i, j;
	for (i = 0; i < N_PRIORITIES; i = i + 1) begin
		for (j = 0; j < N_REQ; j = j + 1) begin
			req_stratified[i][j] = req[j] && priority[W_PRIORITY * j +: W_PRIORITY] == i;
		end
		level_has_req[i] = |req_stratified[i];
	end
end

wire [N_PRIORITIES-1:0] active_layer_sel;

onehot_priority #(
	.W_INPUT (N_PRIORITIES),
	.HIGHEST_WINS (HIGHEST_WINS)
) prisel_layer (
	.in  (level_has_req),
	.out (active_layer_sel)
);

reg [N_REQ-1:0] reqs_from_highest_layer;

always @ (*) begin: mux_reqs_by_layer
	integer i;
	reqs_from_highest_layer = {N_REQ{1'b0}};
	for (i = 0; i < N_PRIORITIES; i = i + 1)
		reqs_from_highest_layer = reqs_from_highest_layer |
			(req_stratified[i] & {N_REQ{active_layer_sel[i]}});
end

onehot_priority #(
	.W_INPUT (N_PRIORITIES)
) prisel_tiebreak (
	.in  (reqs_from_highest_layer),
	.out (gnt)
);

endmodule
