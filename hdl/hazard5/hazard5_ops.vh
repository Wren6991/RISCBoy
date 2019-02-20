
localparam W_ALUOP = 4;
localparam W_ALUSRC = 2;
localparam W_MEMOP = 4;
localparam W_BCOND = 2;

// ALU operation selectors

localparam ALUOP_ADD     = 4'h0; 
localparam ALUOP_SUB     = 4'h1; 
localparam ALUOP_LT      = 4'h2;
localparam ALUOP_LTU     = 4'h4;
localparam ALUOP_AND     = 4'h6;
localparam ALUOP_OR      = 4'h7;
localparam ALUOP_XOR     = 4'h8;
localparam ALUOP_SRL     = 4'h9;
localparam ALUOP_SRA     = 4'ha;
localparam ALUOP_SLL     = 4'hb;


// Parameters to control ALU input muxes. Bypass mux paths are
// controlled by X, so D has no parameters to choose these.

localparam ALUSRCA_RS1      = 2'h0;
localparam ALUSRCA_PC       = 2'h1;

localparam ALUSRCB_RS2      = 2'h0;
localparam ALUSRCB_IMM      = 2'h1;

localparam MEMOP_LW   = 4'h0;
localparam MEMOP_LH   = 4'h1;
localparam MEMOP_LB   = 4'h2;
localparam MEMOP_LHU  = 4'h3;
localparam MEMOP_LBU  = 4'h4;
localparam MEMOP_SW   = 4'h5;
localparam MEMOP_SH   = 4'h6;
localparam MEMOP_SB   = 4'h7;
localparam MEMOP_NONE = 4'h8;

localparam BCOND_NEVER  = 2'h0;
localparam BCOND_ALWAYS = 2'h1;
localparam BCOND_ZERO   = 2'h2;
localparam BCOND_NZERO  = 2'h3;