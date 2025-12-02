module denise_top
(
  inout      [15:0]  D,     // Bi-Directional Data Buffer
  input       [8:1]  RGA,     // Register Address Bus
  input              C7M,     // 7MHz System Clock
  input              CCK,     // 3.5MHz Colour Clock
  input             nCDAC,    // 7MHz Quadrature Clock

  output      [3:0]  RED,     // Red Colour
  output      [3:0]  GRN,     // Green COlour
  output      [3:0]  BLU,     // Blue Colour
  output            nBURST,   // Colour Burst
  output            nCBL,     // Composite Blanking (N/C on normal Denise)
  output            nZD,      // Background Indicator

  input              M0H,     // Mouse 0 Horizontal Quadrature
  input              M1H,     // Mouse 1 Horizontal Quadrature
  input              M0V,     // Mouse 0 Vertical Quadrature
  input              M1V      // Mouse 1 Vertical Quadrature
);

/*  Clock reconstruction
    CCK is a 3.58MHZ clock synced to the falling edge of the 7.16MHz system clock, aka /C1
    CCKQ is a 3.58MHZ clock synced to the rising edge of the 7.16MHz system clock, aka /C3
    CDAC is a 7.16MHz clock that leads the 7.16MHz system clock by 70ns (90 degrees)
  nCDAC is a 7.16MHz clock that is the complement of CDAC

              140ns
            |<----->|
        ___     ___     ___     ___     ___     ___     ___     ___     _
    C7M |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
        |   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|

            |   | 75|   |
            | ->| ns|<- |
            | | |   |   |
        35->| |<-   |   |
        ns ___  |  ___  |  ___     ___     ___     ___     ___     ___
   CDAC   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
        __|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___
            |       |
            |   |   |   |
        ____    |    _______         _______         _______         _____
    CCK     |       |       |       |       |       |       |       |
            |_______|       |_______|       |_______|       |_______|

            |   |   |   |
         _______    |    _______         _______         _______         _
    CCKQ|       |       |       |       |       |       |       |       |
        |       |_______|       |_______|       |_______|       |_______|

*/

// This is the fastest clock we can generate without the PLL
// Note that we'll include a loop back to the PLL in revisions
wire C14M = C7M ~^ nCDAC;

// Regenerate the CCK quadrature
wire CCKQ = C7M  ^ CCK;

wire  [5:0] bpl_bus;        // Bit Plane Bus
wire  [1:0] spr_bus [7:0];  // Sprite Data Bus
wire  [4:0] plx_bus;        // Colour Pixel Bus (to CLUT)
wire [11:0] rgb_bus;        // Colour Output

// Instatiate sub modules
denise_quad m0h(
    .clk(CCKQ),
    .quadMux(M0H),
    .count(r_JOY0DAT[7:0])
);
denise_quad m0v(
    .clk(CCKQ),
    .quadMux(M0V),
    .count(r_JOY0DAT[15:8])
);
denise_quad m1h(
    .clk(CCKQ),
    .quadMux(M1H),
    .count(r_JOY1DAT[7:0])
);
denise_quad m1v(
    .clk(CCKQ),
    .quadMux(M1V),
    .count(r_JOY1DAT[15:8])
);

denise denise_inst(
    .clk(w_clk),
    .cck(w_cck),
    .cdac_r(w_cdac_rise),
    .cdac_f(w_cdac_fall),
    .cfg_ecs(1'b1),
    .cfg_a1k(1'b0),
    .rga(w_rga),
    .dbi(w_dbi),
    .dbo(w_dbo_d),
    .dbo_en(w_dbo_d_en),
    .red(w_red),
    .green(w_green),
    .blue(w_blue),
    .vsync(w_vsync),
    .blank_n(w_blank_n),
    .sol(w_sol),
    .pal_ntsc()
);

denise_clut color_table(
    .clk(clk),
    .cpu_wr(w_cpu_wr),
    .cpu_idx(r_rga_p1[5:1]),
    .cpu_rgb(db_in[11:0]),
    .clut_rd(w_clut_rd),
    .clut_idx(r_clut_idx_p6[4:0]),
    .clut_rgb(w_clut_rgb_p7)
);

endmodule
