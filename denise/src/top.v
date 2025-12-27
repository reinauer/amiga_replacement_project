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

wire       clk_56m;

SB_PLL40_CORE #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000),		// DIVR =  0
    .DIVF(7'b0001111),	// DIVF = 127
    .DIVQ(3'b100),		// DIVQ =  4
    .FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
) pll_inst (
    .REFERENCECLK  (C7M),
    .PLLOUTGLOBAL  (clk_56m),
    .RESETB        (1'b1),
    .BYPASS        (1'b0),
);

///////////////////////////////////////////////////////
// Clock domain crossing : 7 MHz Amiga -> 56 MHz CTP //
///////////////////////////////////////////////////////

reg  [2:0] r_cck_cc_56m;
reg  [7:0] r_cck_56m;
reg  [4:0] r_c7m_cc_56m;
reg  [4:0] r_cdac_cc_56m;
reg        r_cdac_r_56m;
reg        r_cdac_f_56m;
reg  [1:0] r_28m_ctr_56m;
reg        r_28m_edge_56m;
reg        r_28m_ami_56m;
reg  [8:1] r_rga_cc_56m [0:2];
reg [15:0] r_dbi_cc_56m [0:2];

always @(posedge clk_56m) begin
    r_cck_cc_56m    <= {  r_cck_cc_56m[1:0], CCK };
    r_c7m_cc_56m    <= {  r_c7m_cc_56m[3:0], C7M };
    r_cdac_cc_56m   <= { r_cdac_cc_56m[3:0], CDAC_n };
    r_cdac_r_56m    <= ( r_cdac_cc_56m[4:1] == 4'b0011) ? 1'b1 : 1'b0;
    r_cdac_f_56m    <= ( r_cdac_cc_56m[4:1] == 4'b1100) ? 1'b1 : 1'b0;
    r_28m_ami_56m   <= ( r_cdac_cc_56m[4:1] == 4'b0011) // CDAC_n rises
                    || ( r_cdac_cc_56m[4:1] == 4'b1100) // CDAC_n falls
                    || (  r_c7m_cc_56m[4:1] == 4'b0011) // C7M rises
                    || (  r_c7m_cc_56m[4:1] == 4'b1100) // C7M falls
                    ? 1'b1 : 1'b0;

    if (r_28m_ami_56m) begin
    if (r_cdac_f_56m & r_cck_cc_56m[2])
        r_cck_56m <= 8'b00001111;
    else
        r_cck_56m <= { r_cck_56m[6:0], r_cck_56m[7] };
    end

    if (r_28m_ctr_56m == 2'b10) begin
        r_28m_ctr_56m  <= 2'b00;
        r_28m_edge_56m <= 1'b1;
    end else begin
        r_28m_ctr_56m  <= r_28m_ctr_56m + 2'd1;
        r_28m_edge_56m <= 1'b0;
    end

    r_rga_cc_56m[0] <= RGA;
    r_rga_cc_56m[1] <= r_rga_cc_56m[0];
    r_rga_cc_56m[2] <= r_rga_cc_56m[1];

    r_dbi_cc_56m[0] <= DB;
    r_dbi_cc_56m[1] <= r_dbi_cc_56m[0];
    r_dbi_cc_56m[2] <= r_dbi_cc_56m[1];
end

wire        w_clk       = clk_56m;
wire        w_clk_28m   = r_28m_ami_56m;
wire        w_cck       = r_cck_56m[0];
wire        w_cckq      = r_cck_56m[2];
wire        w_28m_edge  = r_28m_edge_56m;
wire        w_cdac_rise = r_cdac_r_56m;
wire        w_cdac_fall = r_cdac_f_56m;
wire  [8:0] w_rga       = r_rga_cc_56m[2];
wire [15:0] w_dbi       = r_dbi_cc_56m[2];

/////////////////////////////
// Instantiate Denise chip //
/////////////////////////////

wire  [3:0] w_red;
wire  [3:0] w_green;
wire  [3:0] w_blue;
wire        w_sol;
wire        w_blank_n;
wire        w_vsync;
wire [15:0] w_dbo_d;
wire        w_dbo_d_en;
wire        w_mode;

wire w_m1h = M1H;
wire w_m0h = M0H;
wire w_m0v = M0V;
wire w_m1v = M1V;

assign w_red = { w_cck, w_cck, w_cck, w_cck };

Denise Denise_inst(
    .clk(w_clk),
    .cck(w_cck),
    .cdac_r(w_cdac_rise),
    .cdac_f(w_cdac_fall),
    .m0h(w_m0h),
    .m0v(w_m0v),
    .m1h(w_m1h),
    .m1v(w_m1v),
    .cfg_ecs(1'b0),
    .cfg_a1k(1'b0),
    .rga(w_rga),
    .db_in(w_dbi),
    .db_out(w_dbo_d),
    .db_oen(w_dbo_d_en),
    // .red(w_red),
    .green(w_green),
    .blue(w_blue),
    .vsync(w_vsync),
    .blank_n(w_blank_n),
    .sol(w_sol),
    .pal_ntsc(),
    .mode(w_mode)
);

///////////////////////////////////////////////////////
// Scan Doubler                                      //
///////////////////////////////////////////////////////

// Amber Amber_inst(
//     .clk28m(),

//     // Config
//     .lr_filter(),   // interpolation filters settings for low resolution
//     .hr_filter(),   // interpolation filters settings for high resolution
//     .scanline(),    // scanline effect enable
//     .dblscan(),     // enable VGA output (enable scandoubler)

//     .htotal(),      // video line length
//     .mode(w_mode),  // display is in hires mode (from bplcon0)
//     // .osd_blank(),   // OSD overlay enable (blank normal video)
//     // .osd_pixel(),   // OSD pixel(video) data

//     // Pixels in
//     .red_in(),      // red componenent video in
//     .grn_in(),      // grn component video in
//     .blu_in(),      // blu component video in
//     ._hsync_in(),   // horizontal synchronisation in
//     // ._vsync_in(),   // vertical synchronisation in
//     // ._csync_in(),   // composite synchronization in

//     // Pixels out
//     .red_out(),     // red componenent video out
//     .grn_out(),     // grn component video out
//     .blu_out(),     // blu component video out
//     ._hsync_out(),  // horizontal synchronisation out
//     // ._vsync_out()   // vertical synchronisation out
// );

wire red_out = red_in;
wire grn_out = grn_in;
wire blu_out = blu_in;


///////////////////////////////////////////////////////
// Clock domain crossing : 56 MHz CTP -> 7 MHz Amiga //
///////////////////////////////////////////////////////

reg [3:0] r_red_cc_56m  [0:2];
reg [3:0] r_grn_cc_56m  [0:2];
reg [3:0] r_blu_cc_56m  [0:2];

reg [15:0] DB_out       [0:2];
reg        DB_out_en    [0:2];

always @(posedge clk_56m) begin
    DB_out_en[0] <= w_dbo_d_en;
    DB_out_en[1] <= DB_out_en[0];
    DB_out_en[2] <= DB_out_en[1];

    DB_out[0] <= w_dbo_d;
    DB_out[1] <= DB_out[0];
    DB_out[2] <= DB_out[1];

    r_red_cc_56m[0] <= w_red;
    r_red_cc_56m[1] <= r_red_cc_56m[0];
    r_red_cc_56m[2] <= r_red_cc_56m[1];

    r_grn_cc_56m[0] <= w_green;
    r_grn_cc_56m[1] <= r_grn_cc_56m[0];
    r_grn_cc_56m[2] <= r_grn_cc_56m[1];

    r_blu_cc_56m[0] <= w_blue;
    r_blu_cc_56m[1] <= r_blu_cc_56m[0];
    r_blu_cc_56m[2] <= r_blu_cc_56m[1];
end

assign DB = (DB_out_e[2]) ? DB_out[2] : 16'hz;

assign RED = r_red_cc_56m[2];
assign GRN = r_grn_cc_56m[2];
assign BLU = r_blu_cc_56m[2];

assign ZD_n = 1;

endmodule