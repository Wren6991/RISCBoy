// Translate accesses from a wider bus segment to a narrower one.
// Accesses may be wider than the downstream databus,
// in which case this module will translate a single source access to multiple
// destination accesses (not a burst), and collate results accordingly.

// TODO: no burst support on either side

module ahbl_narrower #(
	parameter W_ADDR = 32,
	parameter W_SRC_DATA = 32,
	parameter W_DST_DATA = 16
) (
	input  wire                      src_hready,
	output wire                      src_hready_resp,
	output wire                      src_hresp,
	input  wire [W_ADDR-1:0]         src_haddr,
	input  wire                      src_hwrite,
	input  wire [1:0]                src_htrans,
	input  wire [2:0]                src_hsize,
	input  wire [2:0]                src_hburst,
	input  wire [3:0]                src_hprot,
	input  wire                      src_hmastlock,
	input  wire [W_SRC_DATA-1:0]     src_hwdata,
	output wire [W_SRC_DATA-1:0]     src_hrdata,

	output wire                      dst_hready,
	input  wire                      dst_hready_resp,
	input  wire                      dst_hresp,
	output wire [W_ADDR-1:0]         dst_haddr,
	output wire                      dst_hwrite,
	output wire [1:0]                dst_htrans,
	output wire [2:0]                dst_hsize,
	output wire [2:0]                dst_hburst,
	output wire [3:0]                dst_hprot,
	output wire                      dst_hmastlock,
	output wire [W_DST_DATA-1:0]     dst_hwdata,
	input  wire [W_DST_DATA-1:0]     dst_hrdata
);

//synthesis translate_off
initial if (W_SRC_DATA <= W_DST_DATA)
	$fatal("ahbl_narrower destination must be narrower than source");
initial if (1 << $clog2(W_SRC_DATA) != W_SRC_DATA)
	$fatal("ahbl_narrower source width must be pow 2");
initial if (1 << $clog2(W_DST_DATA) != W_DST_DATA)
	$fatal("ahbl_narrower destination width must be pow 2");
// synthesis translate_on

// parameter SRC_HSIZE_MAX = $clog2(W_SRC_DATA / 8);
// parameter DST_HSIZE_MAX = $clog2(W_DST_DATA / 8);

// parameter W_MUXSEL = $clog2(W_SRC_DATA / W_DST_DATA);

// // No need to register src_hwdata, as we can hold that on the bus
// // via hready until we have muxed all the way through it.
// // However we do need a register to accumulate read data as this is
// // received over the course of multiple destination transfers.
// reg [W_SRC_DATA-W_DST_DATA-1:0] rdata_shift;

// // Data bus muxing

// wire [W_MUXSEL-1:0] wdata mux_sel;
// assign dst_hwdata = src_hwdata >> (W_SRC_DATA * wdata_mux);

// // Reads are from incrementing addresses, so the final (=> nonregistered)
// // read will be the most significant (assume little endian)
// wire [W_SRC_DATA-1:0] rdata_full = {src_hrdata, rdata_shift};

// reg [W_SRC_DATA-1:0] rdata_fanout;

// always @ (*) begin: fanout
// 	integer i, j;
// 	for (i = 0; i < W_SRC_DATA / W_DST_DATA; i = i + 1)
// 		rdata_fanout[i * W_DST_DATA +: W_DST_DATA] = dst_hrdata;
// 	// Hopefully synthesis can figure out that these are mutually exclusive,
// 	// and we don't end up with a cascade mux:
// 	for (i = DST_HSIZE_MAX + 1; i <= SRC_HSIZE_MAX; i = i + 1) begin
		
// 	end
// end

endmodule