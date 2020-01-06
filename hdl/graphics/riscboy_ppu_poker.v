 module riscboy_ppu_poker #(
 	parameter W_HADDR = 32,
 	parameter W_HDATA = 32, // Do not modify
	parameter ADDR_MASK = 32'h200fffff,
 	parameter W_COORD = 9
) (
	input  wire               clk,
	input  wire               rst_n,
	input  wire               en,

	input  wire [W_COORD-1:0] beam_x,
	input  wire [W_COORD-1:0] beam_y,
	input  wire               beam_adv,
	output wire               beam_halt_req,

	output wire               bus_vld,
	output wire [W_HADDR-1:0] bus_addr,
	output wire [1:0]         bus_size,
	input  wire               bus_rdy,
	input  wire [W_HDATA-1:0] bus_data,

	output wire               poke_vld,
	output wire [11:0]        poke_addr,
	output wire [W_HDATA-1:0] poke_data,

	input  wire [W_HADDR-1:0] pc_wdata,
	input  wire               pc_wen
);

reg [W_HADDR-1:0] pc;
reg [W_HDATA-1:0] cir;
reg [W_HDATA-1:0] poke_data_reg;

wire [7:0]  instr_opcode  = cir[31:24];
wire [11:0] instr_coord_x = cir[23:12];
wire [11:0] instr_coord_y = cir[11:0];

wire [W_HADDR-1:0] pc_incr = ((pc & ADDR_MASK) + 3'h4) & ADDR_MASK;

wire coord_match =
	(&instr_coord_x || instr_coord_x[W_COORD-1:0] == beam_x) &&
	(&instr_coord_y || instr_coord_y[W_COORD-1:0] == beam_y);

wire instr_wait = instr_opcode == 8'h0;
wire instr_jump = instr_opcode == 8'h1;
wire instr_poke = instr_opcode == 8'h2;


// ----------------------------------------------------------------------------
// Control Logic

localparam W_STATE      = 3;
localparam S_RESET      = 3'd0; // avoid bus requests while reset asserted
localparam S_FETCH      = 3'd1;
localparam S_EXECUTE    = 3'd2;
localparam S_WAIT_DELAY = 3'd3;
localparam S_WAIT       = 3'd4;
localparam S_POKE       = 3'd5;

wire fetch_rdy;

reg [W_STATE-1:0] state;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pc <= {W_HADDR{1'b0}};
		cir <= {W_HADDR{1'b0}};
		poke_data_reg <= {W_HDATA{1'b0}};
		state <= S_RESET;
	end else if (pc_wen) begin
		pc <= pc_wdata & ADDR_MASK;
		state <= S_RESET;
	end else if (en) begin
		case (state)
		S_RESET: begin
			state <= S_FETCH;
		end
		S_FETCH: begin
			if (fetch_rdy) begin
				cir <= bus_data;
				state <= S_EXECUTE;
				pc <= pc_incr;
			end
		end
		S_EXECUTE: begin
			if (instr_wait) begin
				state <= S_WAIT_DELAY;
			end else if (instr_jump) begin
				if (!coord_match) begin
					state <= S_FETCH;
					pc <= pc_incr;
				end else if (fetch_rdy) begin
					state <= S_FETCH;
					pc <= bus_data & ADDR_MASK;
				end
			end else if (instr_poke) begin
				if (fetch_rdy) begin
					state <= S_POKE;
					pc <= pc_incr;
					poke_data_reg <= bus_data;
				end
			//synthesis translate_off
			end else begin
				$display("Unrecognised Poker instruction %h at PC+4 = %h", instr_opcode, pc);
				$finish;
			//synthesis translate_on
			end
		end
		S_WAIT_DELAY: begin
			if (beam_adv)
				state <= S_WAIT;
		end
		S_WAIT: begin
			if (coord_match) begin
				state <= S_FETCH;
			end
		end
		S_POKE: begin
			state <= S_FETCH;
		end
		endcase
	end
end

// ----------------------------------------------------------------------------
// Interfacing

assign beam_halt_req = en && !(state == S_WAIT_DELAY || (state == S_WAIT && !coord_match));

assign poke_vld = state == S_POKE;
assign poke_data = poke_data_reg;
assign poke_addr = cir[11:0];

reg bus_hold;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		bus_hold <= 1'b0;
	else
		bus_hold <= bus_vld && !bus_rdy;

reg bus_dphase_dirty;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		bus_dphase_dirty <= 1'b0;
	end else begin
		bus_dphase_dirty <= (bus_dphase_dirty || (bus_vld && (pc_wen || !en))) && !bus_rdy;
	end
end

assign bus_size = 2'h2;
assign bus_addr = pc;
assign bus_vld = bus_hold || en && (
	state == S_FETCH ||
	state == S_EXECUTE && instr_poke ||
	state == S_EXECUTE && instr_jump && coord_match
);
assign fetch_rdy = bus_rdy && !bus_dphase_dirty;

endmodule
