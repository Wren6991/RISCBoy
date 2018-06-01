module ahbl_to_apb #(
	parameter W_HADDR = 32,
	parameter W_PADDR = 16,
	parameter W_DATA = 32
) (
	input wire clk,
	input wire rst_n,

	input  wire               ahbls_hready,
	output wire               ahbls_hready_resp,
	output wire               ahbls_hresp,
	input  wire [W_HADDR-1:0] ahbls_haddr,
	input  wire               ahbls_hwrite,
	input  wire [1:0]         ahbls_htrans,
	input  wire [2:0]         ahbls_hsize,
	input  wire [2:0]         ahbls_hburst,
	input  wire [3:0]         ahbls_hprot,
	input  wire               ahbls_hmastlock,
	input  wire [W_DATA-1:0]  ahbls_hwdata,
	output wire [W_DATA-1:0]  ahbls_hrdata,

	output reg  [W_PADDR-1:0] apbm_paddr,
	output reg                apbm_psel,
	output reg                apbm_penable,
	output reg                apbm_pwrite,
	output reg  [W_DATA-1:0]  apbm_pwdata,
	input wire                apbm_pready,
	input wire  [W_DATA-1:0]  apbm_prdata,
	input wire                apbm_pslverr 
);

localparam W_APB_STATE = 3;
localparam STATE_RD0 = 3'h0;
localparam STATE_RD1 = 3'h1;
localparam STATE_WR0 = 3'h2;
localparam STATE_WR1 = 3'h3;
localparam STATE_IDLE = 3'h4;

reg [W_APB_STATE-1:0] apb_state;
assign ahbls_hready_resp = ((apb_state == STATE_RD1 || apb_state == STATE_WR1) && apbm_pready) || apb_state == STATE_IDLE;
assign ahbls_hrdata = apbm_prdata;
assign ahbls_hresp = apbm_pslverr;

always @ (*) begin
	case (apb_state)
		STATE_RD0: {apbm_psel, apbm_penable, apbm_pwrite} = 3'b100;
		STATE_RD1: {apbm_psel, apbm_penable, apbm_pwrite} = 3'b110;
		STATE_WR0: {apbm_psel, apbm_penable, apbm_pwrite} = 3'b101;
		STATE_WR1: {apbm_psel, apbm_penable, apbm_pwrite} = 3'b111;
		default:   {apbm_psel, apbm_penable, apbm_pwrite} = 3'b000;
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		apb_state <= STATE_IDLE;
		apbm_paddr <= {W_PADDR{1'b0}};
		apbm_pwdata <= {W_DATA{1'b0}};
	end else begin
		if (apb_state == STATE_WR0) begin
			apbm_pwdata <= ahbls_hwdata;
			apb_state <= STATE_WR1;
		end
		if (apb_state == STATE_RD0) begin
			apb_state <= STATE_RD1;
		end
		if (ahbls_hready) begin
			if (ahbls_htrans[1]) begin
				apbm_paddr <= ahbls_haddr;
				apb_state <= ahbls_hwrite ? STATE_WR0 : STATE_RD0;
			end else begin
				apb_state <= STATE_IDLE;
			end
		end
	end
end

endmodule