module top(
  // CSG 8362R8 Denise chip
  input             M1H,
  input             M0H,

  input      [8:1]  RGA,

  input             BURST_n, // ignored right now

  output     [3:0]  RED,
  output     [3:0]  GRN,
  output     [3:0]  BLU,

  input             CSYNC_n, // ignored right now
  output            ZD_n,    // ignored right now
  input             CDAC_n,
  input             C7M,
  input             CCK,

  input             M0V,
  input             M1V,

  inout      [15:0] DB,
);


//////////////////////////////////////////////////////
// PLL that generates 56 MHz clock from 7 MHz       //
//////////////////////////////////////////////////////

// Note that we do not need the CDAC_n here as it was
// only needed by the ECS chip to generaste a higher
// clock on Super Denise. Here, we're using a PLL and
// can ignore that.

wire clk_56m;
wire w_arst_n;
wire w_c7m_rise;

SB_PLL40_CORE #(
    .FEEDBACK_PATH("SIMPLE"),
    .PLLOUT_SELECT("GENCLK"),
    .DIVR(4'b0000),       // reference divider
    .DIVF(7'b0011111),    // feedback multiplier = 1 + 31 = 32
    .DIVQ(3'b001),        // output divider = 2 * (1 + 1) = 4
    .FILTER_RANGE(3'b001)
) pll_inst (
    .REFERENCECLK  (C7M),
    .PLLOUTGLOBAL  (clk_56m),
    .PLLOUTCORE    (),
    .EXTFEEDBACK   (),
    .DYNAMICDELAY  (),
    .RESETB        (),
    .BYPASS        (1'b0),
    .LOCK          (),
    .SDI           (),
    .SDO           (),
    .SCLK          ()
);

/////////////////////////////////////////////////
// Re-generated CDAC_n clocks @ 56 MHz         //
/////////////////////////////////////////////////
reg [2:0] cdac_edge;
reg [2:0] cckq_edge;
reg [4:0] cckq_count;

wire w_cdac_rise = cdac_edge[2:1] == 2'b01; // 3'b011 to deglitch
wire w_cdac_fall = cdac_edge[2:1] == 2'b10; // 3'b100 to deglitch
wire w_cckq = cckq_count[3:0] == 3'b011; // mid point of CCK
wire w_cck = cckq_count[4];

always @(posedge clk_56m) begin
    cdac_edge <= { cdac_edge[1:0], CDAC_n };
    cckq_edge <= { cckq_edge[1:0], CCK };
    if (cckq_edge[2:1] == 2'b01)
        cckq_count <= 0;
    else
        cckq_count <= cckq_count + 1;
end

/////////////////////////////
// Instantiate Denise chip //
/////////////////////////////
wire        w_clk = clk_56m;
wire  [8:1] w_rga = RGA;

// Data bus
wire [15:0] w_dbi = DB;
wire [15:0] w_dbo_d;
wire        w_dbo_d_en;

assign DB = (w_dbo_d_en) ? w_dbo_d : 16'hz;

// Video output (to Amber)
wire [3:0] w_red;
wire [3:0] w_green;
wire [3:0] w_blue;
wire       w_sol;
wire       w_blank_n;
wire       w_vsync;

wire       w_m1h = M1H;
wire       w_m0h = M0H;
wire       w_m0v = M0V;
wire       w_m1v = M1V;

Denise Denise_inst(
    .clk(w_clk),
    .cck(w_cck),
    .cdac_r(w_cdac_rise),
    .cdac_f(w_cdac_fall),
    .cckq(w_cckq),
    .m0h(w_m0h),
    .m0v(w_m0v),
    .m1h(w_m1h),
    .m1v(w_m1v),
    .cfg_ecs(1'b1),
    .cfg_a1k(1'b0),
    .rga(w_rga),
    .db_in(w_dbi),
    .db_out(w_dbo_d),
    .db_oen(w_dbo_d_en),
    .red(w_red),
    .green(w_green),
    .blue(w_blue),
    .vsync(w_vsync),
    .blank_n(w_blank_n),
    .sol(w_sol),
    .pal_ntsc()
);

/////////////////
// Scandoubler //
/////////////////
// TBRD
assign RED = w_red;
assign GRN = w_green;
assign BLU = w_blue;

assign ZD_n = 1;

endmodule