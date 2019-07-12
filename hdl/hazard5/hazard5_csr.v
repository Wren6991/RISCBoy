/******************************************************************************
 *     DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE         *
 *                        Version 3, April 2008                               *
 *                                                                            *
 *     Copyright (C) 2019 Luke Wren                                           *
 *                                                                            *
 *     Everyone is permitted to copy and distribute verbatim or modified      *
 *     copies of this license document and accompanying software, and         *
 *     changing either is allowed.                                            *
 *                                                                            *
 *       TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION      *
 *                                                                            *
 *     0. You just DO WHAT THE FUCK YOU WANT TO.                              *
 *     1. We're NOT RESPONSIBLE WHEN IT DOESN'T FUCKING WORK.                 *
 *                                                                            *
 *****************************************************************************/

// Control and Status Registers (CSRs)
// Read port is combinatorial.
// Write port is registered, writes are visible on next cycle.

module hazard5_csr #(
	parameter W_DATA          = 32,
	parameter CSR_M_MANDATORY = 0, // Include mandatory M-mode CSRs
	parameter CSR_M_TRAP      = 0, // Include M-mode trap-handling CSRs
	parameter CSR_COUNTER     = 0, // Include counter/timer CSRs
	parameter EXTENSION_C     = 0, // For misa
	parameter EXTENSION_M     = 0  // For misa
) (
	input  wire              clk,
	input  wire              rst_n,

	input  wire [11:0]       addr,
	input  wire [W_DATA-1:0] wdata,
	input  wire              wen,
	input  wire [1:0]        wtype,
	output reg  [W_DATA-1:0] rdata,
	input  wire              ren,

	output reg               error
);

`include "hazard5_ops.vh"

// ----------------------------------------------------------------------------
// List of M-mode CSRs (we implement a configurable subset of M-mode).
// The CSR block is the only piece of hardware which needs to know this mapping.

// Machine Information Registers (RO)
localparam MVENDORID  = 12'hf11; // Vendor ID.
localparam MARCHID    = 12'hf12; // Architecture ID.
localparam MIMPID     = 12'hf13; // Implementation ID.
localparam MHARTID    = 12'hf14; // Hardware thread ID.

// Machine Trap Setup (RW)
localparam MSTATUS    = 12'h300; // Machine status register.
localparam MISA       = 12'h301; // ISA and extensions
localparam MEDELEG    = 12'h302; // Machine exception delegation register.
localparam MIDELEG    = 12'h303; // Machine interrupt delegation register.
localparam MIE        = 12'h304; // Machine interrupt-enable register.
localparam MTVEC      = 12'h305; // Machine trap-handler base address.
localparam MCOUNTEREN = 12'h306; // Machine counter enable.

// Machine Trap Handling (RW)
localparam MSCRATCH   = 12'h340; // Scratch register for machine trap handlers.
localparam MEPC       = 12'h341; // Machine exception program counter.
localparam MCAUSE     = 12'h342; // Machine trap cause.
localparam MTVAL      = 12'h343; // Machine bad address or instruction.
localparam MIP        = 12'h344; // Machine interrupt pending.

// Machine Memory Protection (RW)
localparam PMPCFG0    = 12'h3a0; // Physical memory protection configuration.
localparam PMPCFG1    = 12'h3a1; // Physical memory protection configuration, RV32 only.
localparam PMPCFG2    = 12'h3a2; // Physical memory protection configuration.
localparam PMPCFG3    = 12'h3a3; // Physical memory protection configuration, RV32 only.
localparam PMPADDR0   = 12'h3b0; // Physical memory protection address register.
localparam PMPADDR1   = 12'h3b1; // Physical memory protection address register.

// ----------------------------------------------------------------------------
// CSR state + update logic
// Names are (reg)_(field)

reg mstatus_mpie;
reg mstatus_mie;

// Interrupt enable shuffling
// TODO

always @ (posedge clk or negedge rst_n) begin
	mstatus_mpie <= 1'b0;
	mstatus_mie <= 1'b0;
end
// ----------------------------------------------------------------------------
// Read port + detect addressing of unmapped CSRs

reg decode_match;

always @ (*) begin
	decode_match = 1'b0;
	rdata = {W_DATA{1'b0}};
	case (addr)
	MISA: if (CSR_M_MANDATORY) begin
		// WARL, so it is legal to be tied constant
		decode_match = 1'b1;
		rdata = {
			2'h1,              // MXL: 32-bit
			{W_DATA-28{1'b0}}, // WLRL

			13'd0,             // Z...N, no
			|EXTENSION_M,
			3'd0,              // L...J, no
			1'b1,              // Integer ISA
			5'd0,              // H...D, no
			|EXTENSION_C,
			2'b0
		};
	end
	MVENDORID: if (CSR_M_MANDATORY) begin
		decode_match = 1'b1;
		// I don't have a JEDEC ID. It is legal to tie this to 0 if non-commercial.
		rdata = {W_DATA{1'b0}};
	end
	MARCHID: if (CSR_M_MANDATORY) begin
		decode_match = 1'b1;
		// I don't have a RV foundation ID. It is legal to tie this to 0.
		rdata = {W_DATA{1'b0}};
	end
	MIMPID: if (CSR_M_MANDATORY) begin
		decode_match = 1'b1;
		// TODO put git SHA or something here
		rdata = {W_DATA{1'b0}};
	end
	MHARTID: if (CSR_M_MANDATORY) begin
		decode_match = 1'b1;
		// There is only one hart, and spec says this must be numbered 0.
		rdata = {W_DATA{1'b0}};
	end

	MSTATUS: if (CSR_M_MANDATORY) begin
		decode_match = 1'b1;
		rdata = {
			1'b0,    // Never any dirty state besides GPRs
			8'd0,    // (WPRI)
			1'b0,    // TSR (Trap SRET), tied 0 if no S mode.
			1'b0,    // TW (Timeout Wait), tied 0 if only M mode.
			1'b0,    // TVM (trap virtual memory), tied 0 if no S mode.
			1'b0,    // MXR (Make eXecutable Readable), tied 0 if not S mode.
			1'b0,    // SUM, tied 0, we have no S or U mode
			1'b0,    // MPRV (modify privilege), tied 0 if no U mode
			4'd0,    // XS, FS always "off" (no extension state to clear!)
			2'b11,   // MPP (M-mode previous privilege), we are always M-mode
			2'd0,    // (WPRI)
			1'b0,    // SPP, tied 0 if S mode not supported
			mstatus_mpie,
			3'd0,    // No S, U
			mstatus_mie,
			3'd0     // No S, U
		};
	end
	MTVEC: if (CSR_M_MANDATORY) begin
		decode_match = 1'b1;
		rdata = {
			{W_DATA-2{1'b0}}, // BASE is a WARL field, tie off for now
			2'h1              // MODE = Vectored (Direct is useless)
		};
	end
	// MEDELEG, MIDELEG should not exist for M-only implementations. Will raise
	// illegal instruction exception if accessed.
	default: begin end
	endcase
end


always @ (*)
	error = (wen || ren) && !decode_match;

endmodule
