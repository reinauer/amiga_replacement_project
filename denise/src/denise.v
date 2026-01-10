// Copyright 2011, 2012 Frederic Requin
// Copyright 2024, 2025 Renee Cousins, The Buffee project, Inc
//  
// See README.md for details

module Denise
(
  // Main clock
  input             clk,       // Master clock (28/56/85 MHz)
  // Generated clocks
  input             cck,       // CCK clock
  input             cckq,      // CCK quadrature clock
  input             cck_edge,  // CCK edge
  input             cckq_edge, // CCKQ edge
  input             cdac_edge, // CDAC edge

  // Mouse/Joystick
  input             m0h,
  input             m0v,
  input             m1h,
  input             m1v,

  // Configuration
  input             cfg_ecs,   // OCS(0) or ECS(1) chipset
  input             cfg_a1k,   // Normal mode(0), A1000 mode(1)

  // Busses
  input       [8:1] rga,       // RGA bus
  input      [15:0] db_in,     // Data bus input
  output     [15:0] db_out,    // Data bus output
  output            db_oen,    // Data bus output enable

  // Video output
  output      [3:0] red,       // Red component output
  output      [3:0] green,     // Green component output
  output      [3:0] blue,      // Blue component output
  output reg        vsync,     // Vertical synchro
  output            blank_n,   // Composite blanking
  output reg        sol,       // Start of line (HPOS = 32)
  output            pal_ntsc   // PAL (1), NSTC (0) flag
);

///////////////////////////////
// Register address decoding //
///////////////////////////////

reg  [8:1] r_rga_p1;
always@(posedge clk) begin
  if (cck_edge & cck) begin
        // Latch RGA bits for next cycle
        r_rga_p1 <= rga;//[5:1];
  end
end

// Comparators
wire       w_rregs_joy0_p1 = (r_rga_p1[8:1] == 8'b0_0000_101); // JOYxDAT  : $00A
wire       w_rregs_joy1_p1 = (r_rga_p1[8:1] == 8'b0_0000_110); // JOYxDAT  : $00C
wire       w_rregs_clx_p1  = (r_rga_p1[8:1] == 8'b0_0000_111); // CLXDAT   : $00E
wire       w_rregs_id_p1   = (r_rga_p1[8:1] == 8'b0_0111_110); // DENISEID : $07C

wire       w_wregs_joyw_p1 = (r_rga_p1[8:1] == 8'b0_0011_011); // JOYTEST  : $036
wire       w_wregs_str_p1  = (r_rga_p1[8:1] == 8'b0_0011_1xx); // Strobes  : $038 - $03E
wire       w_wregs_diwb_p1 = (r_rga_p1[8:1] == 8'b0_1000_111); // DIWSTRT  : $08E
wire       w_wregs_diwe_p1 = (r_rga_p1[8:1] == 8'b0_1001_000); // DIWSTOP  : $090
wire       w_wregs_clx_p1  = (r_rga_p1[8:1] == 8'b0_1001_100); // CLXCON   : $098
wire       w_wregs_ctl_p1  = (r_rga_p1[8:1] == 8'b1_0000_0xx); // BPLCONx  : $100 - $106
wire       w_wregs_bpl_p1  = (r_rga_p1[8:1] == 8'b1_0001_xxx); // BPLxDAT  : $110 - $11E
wire       w_wregs_spr_p1  = (r_rga_p1[8:1] == 8'b1_01xx_xxx); // Sprites  : $140 - $17E
wire       w_wregs_clut_p1 = (r_rga_p1[8:1] == 8'b1_10xx_xxx); // Color    : $180 - $1BE
wire       w_wregs_diwh_p1 = (r_rga_p1[8:1] == 8'b1_1110_010); // DIWHIGH  : $1E4

wire [15:0] jm_db_out;
wire [15:0] clx_db_out;
wire w_denise_id = w_rregs_id_p1 && cfg_ecs;

assign db_out = jm_db_out | clx_db_out | (w_denise_id ? 16'hFFFC : 16'd0);
assign db_oen = w_rregs_clx_p1 | w_rregs_joy0_p1 | w_rregs_joy1_p1 | w_denise_id;

// Implement Joystick & Mouse decoder
JoyMouse joymouse(
  .clk(clk),
  .cck(cck),
  .cck_edge(cck_edge),
  .m0h(m0h),
  .m0v(m0v),
  .m1h(m1h),
  .m1v(m1v),
  .w_rregs_joy0_p1(w_rregs_joy0_p1),
  .w_rregs_joy1_p1(w_rregs_joy1_p1),
  .w_wregs_joyw_p1(w_wregs_joyw_p1),
  .db_in(db_in),
  .db_out(jm_db_out)
);

wire [5:0] bpl_data = w_pf_data_p4;
// wire [1:0] spr_data [0:7];
// reg [1:0] r_spr_pix_p1 [0:7];

// Pack sprite data
// wire [15:0] spr_data_flat = {
//   spr_data[7],spr_data[6],spr_data[5],spr_data[4],
//   spr_data[3],spr_data[2],spr_data[1],spr_data[0] };
wire [15:0] spr_data_flat = {
  r_spr_pix_p1[7],r_spr_pix_p1[6],r_spr_pix_p1[5],r_spr_pix_p1[4],
  r_spr_pix_p1[3],r_spr_pix_p1[2],r_spr_pix_p1[1],r_spr_pix_p1[0] };

// Implement Collision
Collision collision(
  .clk(clk),
  .cck_pos_edge(cck_edge && cck),
  .w_wregs_clx_p1(w_wregs_clx_p1),
  .w_rregs_clx_p1(w_rregs_clx_p1),
  .db_in(db_in),
  .db_out(clx_db_out),
  .bpl_data(bpl_data),
  .spr_data_flat(spr_data_flat)
);

///////////////////
// PAL/NTSC flag //
///////////////////

reg [1:0] r_str_ctr;

always@(posedge clk) begin
  if (cck_edge & cck) begin
    if (w_wregs_str_p1) begin
      // STRLONG strobes reset the counter
      if (r_rga_p1[2:1] == 2'b11)
        r_str_ctr <= 2'b00;
      else if (r_str_ctr != 2'b11)
        r_str_ctr <= r_str_ctr + 2'd1;
    end
  end
end

assign pal_ntsc = &r_str_ctr;

//////////////////////
// Vertical synchro //
//////////////////////

reg [3:0] r_equ_ctr;

always@(posedge clk) begin
  if (cck_edge & cck) begin
    if (w_wregs_str_p1) begin
      // Discard STRLONG strobes
      if (r_rga_p1[2:1] != 2'b11) begin
        // STREQU strobes increment counter
        if (r_rga_p1[2:1] == 2'b00)
          r_equ_ctr <= r_equ_ctr + 4'd1;
        // STRVBL and STRHOR strobes clear it
        else
          r_equ_ctr <= 4'd0;
      end
    end
  end
  if (cck_edge) begin
    if (sol) begin
      vsync <= |r_equ_ctr;
    end
  end
end

////////////////////////
// Horizontal counter //
////////////////////////

wire      w_hpos_clr;
wire      w_hpos_dis;
reg [8:0] r_hpos;
reg       r_lol_ena;

// HPOS clear conditions
assign w_hpos_clr = (((r_rga_p1[2:1] == 2'b00) && (cfg_ecs)) || 
                     (r_rga_p1[2:1] == 2'b01) ||
                     (r_rga_p1[2:1] == 2'b10)) ? (w_wregs_str_p1 & cck) : 1'b0;
// HPOS disable conditions
assign w_hpos_dis = (r_rga_p1[2:1] == 2'b11) ? (w_wregs_str_p1 & cck) : 1'b0;

always@(posedge clk) begin
  if (cck_edge) begin
    if (w_hpos_clr) begin
      // STREQU (ECS only), STRVBL or STRHOR : HPOS starts at 2
      r_hpos    <= 9'd2;
      r_lol_ena <= 1'b0;
    end else begin
      // STRLONG : long line, disable HPOS counting during 1 clock cycle
      if (w_hpos_dis)
        r_lol_ena <= 1'b1;
      else
        r_hpos    <= r_hpos + 9'd1;
    end
  end
  // Start of line flag for external scandoubler
  if (r_hpos == 9'd32)
    if (cckq_edge) sol <= 1'b1;
  else
    if (cck_edge) sol <= 1'b0;
end

///////////////////////////////
// Horizontal display window //
///////////////////////////////

reg [8:0] r_HDIWSTRT;
reg [8:0] r_HDIWSTOP;
reg       r_hwin_ena_p0;
reg       r_hwin_ena_p1;
reg       r_hwin_ena_p2;
reg       r_vwin_ena_p0;

always@(posedge clk) begin
  if (cck_edge & cck) begin
    // DIWSTRT
    if (w_wregs_diwb_p1)
      r_HDIWSTRT <= { 1'b0, db_in[7:0] };
    // DIWSTOP
    if (w_wregs_diwe_p1)
      r_HDIWSTOP <= { 1'b1, db_in[7:0] };
    // DIWHIGH
    if ((w_wregs_diwh_p1) && (cfg_ecs)) begin
      r_HDIWSTRT[8] <= db_in[5];
      r_HDIWSTOP[8] <= db_in[13];
    end
  end
end

always@(posedge clk) begin
  if (cckq_edge) begin
    // Display window horizontal start
    if (r_hpos == r_HDIWSTRT)
      r_hwin_ena_p0 <= 1'b1;
    // Display window horizontal stop
    else if (r_hpos == r_HDIWSTOP)
      r_hwin_ena_p0 <= 1'b0;
    // Vertical window
    if (r_hpos == 9'h013)
      r_vwin_ena_p0 <= 1'b0;
    else if (w_wregs_bpl_p1)
      r_vwin_ena_p0 <= 1'b1;
    // Delayed horizontal + vertical window
    r_hwin_ena_p1 <= r_hwin_ena_p0 & r_vwin_ena_p0;
    r_hwin_ena_p2 <= r_hwin_ena_p1;
  end
end

///////////////////////
// Vertical blanking //
///////////////////////

reg  r_vblank_p2;

always@(posedge clk) begin
  if (cck_edge & cck) begin
    // Vertical blanking only during STREQU and STRVBL
    if ((w_wregs_str_p1) && (r_rga_p1[2:1] != 2'b11))
      r_vblank_p2 <= ~r_rga_p1[2];
  end
end

/////////////////////////
// Horizontal blanking //
/////////////////////////

reg  r_hblank_p3;

always@(posedge clk) begin
  //if (cckq_edge) begin
  //  r_hblank_p3 <= ~r_hwin_ena_p2;
  //end
  if (cck_edge) begin
    if (r_hpos == 9'h013)
      r_hblank_p3 <= 1'b1;
    else if (r_hpos == 9'h061)
      r_hblank_p3 <= 1'b0;
  end
end

////////////////////////
// Composite blanking //
////////////////////////

reg  r_cblank_p4;

// (BUG!! but implemented this way on real HW)
always@(posedge clk) begin
  if (cckq_edge) begin
    r_cblank_p4 <= r_hblank_p3 | r_vblank_p2;
  end
end

////////////////////
// Bitplanes data //
////////////////////

reg [15:0] r_BPLxDAT_p2 [0:7];
reg        r_bpl_load_p3;
reg  [3:0] r_ddf_dly_p3;

always@(posedge clk) begin
  if (cck_edge) begin
    if ((w_wregs_bpl_p1) && (cck)) begin
      // Load BPLxDAT register (6 & 7 unused)
      r_BPLxDAT_p2[r_rga_p1[3:1]] <= db_in[15:0];
      // BPL1DAT is written : 
      if (r_rga_p1[3:1] == 3'b000) begin
        // Trigger loading of second stage registers
        r_bpl_load_p3 <= 1'b1;
        // Non-aligned DDFSTRT delay
        r_ddf_dly_p3[3] <= r_hpos[3] & ~(r_HIRES | r_SHRES);
        r_ddf_dly_p3[2] <= r_hpos[2] & ~r_SHRES;
        r_ddf_dly_p3[1] <= r_hpos[1];
        r_ddf_dly_p3[0] <= 1'b0;
      end
    end else
      r_bpl_load_p3 <= 1'b0;
  end
end

////////////////////////////////////
// Playfields scrolling + shifter //
////////////////////////////////////

reg       r_HIRES;
reg       r_SHRES;
reg [3:0] r_BPU;
reg       r_HOMOD;
reg       r_DBLPF;

// BPLCON0 register
always@(posedge clk) begin
  if (cck_edge & cck) begin
    if ((w_wregs_ctl_p1) && (r_rga_p1[2:1] == 2'b00)) begin
      r_HIRES <= db_in[15];
      //r_BPU   <= { db_in[4], db_in[14:12] };
      r_BPU   <= { 1'b0, db_in[14:12] };
      r_HOMOD <= db_in[11];
      r_DBLPF <= db_in[10];
      r_SHRES <= db_in[6] && cfg_ecs;
    end
  end
end

reg [3:0] r_PF1H;
reg [3:0] r_PF2H;

// BPLCON1 register
always@(posedge clk) begin
  if (cck_edge & cck) begin
    if ((w_wregs_ctl_p1) && (r_rga_p1[2:1] == 2'b01)) begin
      r_PF1H <= db_in[3:0];
      r_PF2H <= db_in[7:4];
    end
  end
end

reg [4:0]  r_pf_dly_p3;

// Counter that keeps track of playfield delay
always@(posedge clk) begin
  if (cckq_edge) begin
    if (r_bpl_load_p3)
      // Cleared when BPL1DAT is written
      r_pf_dly_p3 <= 5'b10000;
    else if (r_pf_dly_p3[4])
      // Incremented otherwise
      r_pf_dly_p3 <= r_pf_dly_p3 + 5'd1;
  end
end

reg [15:0] r_pf1dat_p4 [0:2];
reg [15:0] r_pf2dat_p4 [0:2];

wire w_pixel_clk = (cckq_edge) || (cck_edge && (r_HIRES || r_SHRES)) || (cdac_edge && r_SHRES);

// Playfields delays and shifters
always@(posedge clk) begin
  if (w_pixel_clk) begin
    if (((r_pf_dly_p3[3:0] ^ r_ddf_dly_p3) == r_PF1H) && (cckq_edge) && (r_pf_dly_p3[4])) begin
      // Playfield #1 delay
      r_pf1dat_p4[0] <= r_BPLxDAT_p2[0];
      r_pf1dat_p4[1] <= r_BPLxDAT_p2[2];
      r_pf1dat_p4[2] <= r_BPLxDAT_p2[4];
    end else begin
      // Playfield #1 shifter
      r_pf1dat_p4[0] <= { r_pf1dat_p4[0][14:0], 1'b0 };
      r_pf1dat_p4[1] <= { r_pf1dat_p4[1][14:0], 1'b0 };
      r_pf1dat_p4[2] <= { r_pf1dat_p4[2][14:0], 1'b0 };
    end
    if (((r_pf_dly_p3[3:0] ^ r_ddf_dly_p3) == r_PF2H) && (cckq_edge) && (r_pf_dly_p3[4])) begin
      // Playfield #2 delay
      r_pf2dat_p4[0] <= r_BPLxDAT_p2[1];
      r_pf2dat_p4[1] <= r_BPLxDAT_p2[3];
      r_pf2dat_p4[2] <= r_BPLxDAT_p2[5];
    end else begin
      // Playfield #2 shifter
      r_pf2dat_p4[0] <= { r_pf2dat_p4[0][14:0], 1'b0 };
      r_pf2dat_p4[1] <= { r_pf2dat_p4[1][14:0], 1'b0 };
      r_pf2dat_p4[2] <= { r_pf2dat_p4[2][14:0], 1'b0 };
    end
  end
end

//////////////////////////////////////
// 140 ns delay for NTSC long lines //
//////////////////////////////////////

wire [5:0] w_pf_data_p4;
reg  [5:0] r_pf_lol0_p4;
reg  [5:0] r_pf_lol1_p4;
wire [5:0] w_pf_lol_p4;

assign w_pf_data_p4[0] = r_pf1dat_p4[0][15] & r_bpl_ena[0];
assign w_pf_data_p4[1] = r_pf2dat_p4[0][15] & r_bpl_ena[1];
assign w_pf_data_p4[2] = r_pf1dat_p4[1][15] & r_bpl_ena[2];
assign w_pf_data_p4[3] = r_pf2dat_p4[1][15] & r_bpl_ena[3];
assign w_pf_data_p4[4] = r_pf1dat_p4[2][15] & r_bpl_ena[4];
assign w_pf_data_p4[5] = r_pf2dat_p4[2][15] & r_bpl_ena[5];

always@(posedge clk) begin
  if (cck_edge | cckq_edge) begin
    r_pf_lol0_p4 <= w_pf_data_p4;
    r_pf_lol1_p4 <= r_pf_lol0_p4;
  end
end

assign w_pf_lol_p4 = (r_lol_ena) ? r_pf_lol1_p4 : w_pf_data_p4;

///////////////////////////////
// Playfields priority logic //
///////////////////////////////

reg       r_PF2PRI;
reg [2:0] r_PF2P;
reg [2:0] r_PF1P;

// BPLCON2 register
always@(posedge clk) begin
  if (cck_edge & cck) begin
    if ((w_wregs_ctl_p1) && (r_rga_p1[2:1] == 2'b10)) begin
      r_PF2PRI <= db_in[6];
      r_PF2P   <= db_in[5:3];
      r_PF1P   <= db_in[2:0];
    end
  end
end

reg [7:0] r_bpl_ena;

// Bitplanes enable
always@(posedge clk) begin
  if (cck_edge & cck) begin
    // Bitplane enable flags updated during BPL1DAT write
    if ((w_wregs_bpl_p1) && (r_rga_p1[3:1] == 3'b000)) begin
      case (r_BPU)
        4'd0    : r_bpl_ena <= 8'b00000000;
        4'd1    : r_bpl_ena <= 8'b00000001;
        4'd2    : r_bpl_ena <= 8'b00000011;
        4'd3    : r_bpl_ena <= 8'b00000111;
        4'd4    : r_bpl_ena <= 8'b00001111;
        4'd5    : r_bpl_ena <= 8'b00011111;
        4'd6    : r_bpl_ena <= 8'b00111111;
        4'd7    : r_bpl_ena <= 8'b01111111;
        default : r_bpl_ena <= 8'b11111111;
      endcase
    end
  end
end

reg [5:0] r_pf_data_p4;
reg [1:0] r_pf_vld_p5;
reg [5:0] r_bpl_clx_p5;
reg [5:0] r_bpl_clut_p5;

always@(posedge clk) begin
  if (cck_edge | cckq_edge | cdac_edge) begin
    // Masked playfields data
    r_pf_data_p4[0] = w_pf_lol_p4[0] & r_bpl_ena[0] & r_hwin_ena_p2;
    r_pf_data_p4[1] = w_pf_lol_p4[1] & r_bpl_ena[1] & r_hwin_ena_p2;
    r_pf_data_p4[2] = w_pf_lol_p4[2] & r_bpl_ena[2] & r_hwin_ena_p2;
    r_pf_data_p4[3] = w_pf_lol_p4[3] & r_bpl_ena[3] & r_hwin_ena_p2;
    r_pf_data_p4[4] = w_pf_lol_p4[4] & r_bpl_ena[4] & r_hwin_ena_p2;
    r_pf_data_p4[5] = w_pf_lol_p4[5] & r_bpl_ena[5] & r_hwin_ena_p2;
    
    // Playfields valid signal
    if (r_DBLPF) begin
      // Dual playfield mode
      r_pf_vld_p5[0] = r_pf_data_p4[0] | r_pf_data_p4[2] | r_pf_data_p4[4];
      r_pf_vld_p5[1] = r_pf_data_p4[1] | r_pf_data_p4[3] | r_pf_data_p4[5];
    end else begin
      // Single playfield mode
      r_pf_vld_p5[0] = 1'b0;
      r_pf_vld_p5[1] = |r_pf_data_p4;
    end
 
    // Playfields 1 & 2 priority logic
    if (r_DBLPF) begin
      // Dual playfield mode
      if (r_PF2PRI) begin
        // PF2 has priority
        case (r_pf_vld_p5)
          2'b00   : r_bpl_clut_p5 <= 6'b000000;
          2'b01   : r_bpl_clut_p5 <= { 3'b000, r_pf_data_p4[4], r_pf_data_p4[2], r_pf_data_p4[0] };
          default : r_bpl_clut_p5 <= { 3'b001, r_pf_data_p4[5], r_pf_data_p4[3], r_pf_data_p4[1] };
        endcase
      end
      else begin
        // PF1 has priority
        case (r_pf_vld_p5)
          2'b00   : r_bpl_clut_p5 <= 6'b000000;
          2'b10   : r_bpl_clut_p5 <= { 3'b001, r_pf_data_p4[5], r_pf_data_p4[3], r_pf_data_p4[1] };
          default : r_bpl_clut_p5 <= { 3'b000, r_pf_data_p4[4], r_pf_data_p4[2], r_pf_data_p4[0] };
        endcase
      end
    end else begin
      // Single playfield mode
      // OCS/ECS undocumented behaviour
      // PF2P > 5 (BPLCON2) and BITPLANES == 5 and NOT AGA
      // - pixel in bitplane 5 = zero: planes 1-4 work normally (any color from 0-15 is possible)
      // - pixel in bitplane 5 = one: planes 1-4 are disabled, only pixel from plane 5 is shown (color 16 is visible)
      if ((r_PF2P[2:1] == 2'b11) && (r_BPU == 4'd5) && (r_pf_data_p4[4]))
        r_bpl_clut_p5 <= 6'b010000;
      else
        // Normal behaviour
        r_bpl_clut_p5 <= r_pf_data_p4;
    end

    // Bitplanes collisions data
    r_bpl_clx_p5 <= (r_pf_data_p4 ^ ~r_MVBP) | (~r_ENBP);
  end
end

////////////////////////////////
// Sprites data and positions //
////////////////////////////////

integer i;

reg        r_armed       [0:7];
reg        r_SPRATT      [0:7];
reg [8:0]  r_SPRHPOS     [0:7];
reg [15:0] r_SPRDATA     [0:7];
reg [15:0] r_SPRDATB     [0:7];
reg [15:0] r_spr_shift_A [0:7];
reg [15:0] r_spr_shift_B [0:7];

// SPRxPOS,  SPRxCTL, SPRxDATA and SPRxDATB registers
always@(posedge clk) begin
  if (cck_edge) begin
    if ((w_wregs_spr_p1) && (cck)) begin
      case (r_rga_p1[2:1])
        2'b00 : // SPRxPOS register
        begin
          r_SPRHPOS[r_rga_p1[5:3]][8:1] <= db_in[7:0];
        end
        2'b01 : // SPRxCTL register
        begin
          r_SPRATT[r_rga_p1[5:3]]       <= db_in[7];
          r_SPRHPOS[r_rga_p1[5:3]][0]   <= db_in[0];
          r_armed[r_rga_p1[5:3]]        <= 1'b0; // Sprite disabled
        end
        2'b10 : // SPRxDATA register
        begin
          r_SPRDATA[r_rga_p1[5:3]]      <= db_in[15:0];
          r_armed[r_rga_p1[5:3]]        <= 1'b1; // Sprite enabled
        end
        2'b11 : // SPRxDATB register
        begin
          r_SPRDATB[r_rga_p1[5:3]]      <= db_in[15:0];
        end
      endcase
    end
  end
end

always@(posedge clk) begin
  if (cck_edge) begin
    // Sprites shift registers
    for (i = 0; i < 8; i = i + 1) begin
        if ((r_hpos == r_SPRHPOS[i]) && r_armed[i]) begin
            r_spr_shift_A[i] <= r_SPRDATA[i];
            r_spr_shift_B[i] <= r_SPRDATB[i];
        end else begin
            r_spr_shift_A[i] <= { r_spr_shift_A[i][14:0], 1'b0 };
            r_spr_shift_B[i] <= { r_spr_shift_B[i][14:0], 1'b0 };
        end
    end
  end
end

////////////////////////
// Sprites priorities //
////////////////////////

reg [1:0] r_spr_pix_p1 [0:7];
reg [3:0] r_spr_grp_p0;
reg [2:0] r_spr_vis_p1;

// Sprites pixels and groups
always@(posedge clk) begin
  if (cck_edge) begin
    // Sprites pixels values (shift registers outputs)
    for (i = 0; i < 8; i = i + 1) begin
      r_spr_pix_p1[i][0] <= r_spr_shift_A[i][15];
      r_spr_pix_p1[i][1] <= r_spr_shift_B[i][15];
    end
    // Sprites #0 and #1 => group #0
    r_spr_grp_p0[0] = ((r_spr_shift_A[0][15] | r_spr_shift_B[0][15]))
                    | ((r_spr_shift_A[1][15] | r_spr_shift_B[1][15]));
    // Sprites #2 and #3 => group #1
    r_spr_grp_p0[1] = ((r_spr_shift_A[2][15] | r_spr_shift_B[2][15]))
                    | ((r_spr_shift_A[3][15] | r_spr_shift_B[3][15]));
    // Sprites #4 and #5 => group #2
    r_spr_grp_p0[2] = ((r_spr_shift_A[4][15] | r_spr_shift_B[4][15]))
                    | ((r_spr_shift_A[5][15] | r_spr_shift_B[5][15]));
    // Sprites #6 and #7 => group #3
    r_spr_grp_p0[3] = ((r_spr_shift_A[6][15] | r_spr_shift_B[6][15]))
                    | ((r_spr_shift_A[7][15] | r_spr_shift_B[7][15]));
    // Visible group number
    case (r_spr_grp_p0)
      4'b0000 : r_spr_vis_p1 <= 3'd7; // No sprite visible
      4'b0001 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      4'b0010 : r_spr_vis_p1 <= 3'd1; // Sprite #2 or #3 visible
      4'b0011 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      4'b0100 : r_spr_vis_p1 <= 3'd2; // Sprite #4 or #5 visible
      4'b0101 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      4'b0110 : r_spr_vis_p1 <= 3'd1; // Sprite #2 or #3 visible
      4'b0111 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      4'b1000 : r_spr_vis_p1 <= 3'd3; // Sprite #6 or #7 visible
      4'b1001 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      4'b1010 : r_spr_vis_p1 <= 3'd1; // Sprite #2 or #3 visible
      4'b1011 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      4'b1100 : r_spr_vis_p1 <= 3'd2; // Sprite #4 or #5 visible
      4'b1101 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      4'b1110 : r_spr_vis_p1 <= 3'd1; // Sprite #2 or #3 visible
      4'b1111 : r_spr_vis_p1 <= 3'd0; // Sprite #0 or #1 visible
      default : ;
    endcase
  end
end

reg [2:0] v_idx_e_p1;
reg [2:0] v_idx_o_p1;
reg       r_spr_att_p3;
reg [1:0] r_spr_odd_p3;
reg [1:0] r_spr_even_p3;
reg [2:0] r_spr_vis_p3;
reg [3:0] r_spr_clut_p5;
reg [2:0] r_spr_vis_p5;

// Sprites-sprites priority logic
always@(posedge clk) begin
  if (cck_edge) begin
    // Sprites indexes
    v_idx_e_p1    = { r_spr_vis_p1[1:0], 1'b0 }; // Even (0, 2, 4 ,6)
    v_idx_o_p1    = { r_spr_vis_p1[1:0], 1'b1 }; // Odd (1, 3, 5, 7)
    // Sprite attached flag
    r_spr_att_p3  <= r_SPRATT[v_idx_o_p1] | (r_SPRATT[v_idx_e_p1] & cfg_ecs);
    // Odd and even sprites
    r_spr_odd_p3  <= r_spr_pix_p1[v_idx_o_p1];
    r_spr_even_p3 <= r_spr_pix_p1[v_idx_e_p1];
    // Visible sprite index (masked by the horizontal window)
    r_spr_vis_p3  <= r_spr_vis_p1 | {3{~r_hwin_ena_p1}};
    
    if (r_spr_att_p3)
      // Attached mode : 15-color sprite
      r_spr_clut_p5 <= { r_spr_odd_p3, r_spr_even_p3 };
    else begin
      // Normal mode : choose between odd and even sprite
      if (r_spr_even_p3 != 2'b00) begin
        // Show even sprite with 3 colors
        r_spr_clut_p5 <= { r_spr_vis_p3[1:0], r_spr_even_p3 };
      end
      else begin
        // Show odd sprite with 3 colors
        r_spr_clut_p5 <= { r_spr_vis_p3[1:0], r_spr_odd_p3 };
      end
    end
    // Sprite visible flags
    // [0] : PF1 is in front of sprites
    // [1] : PF2 is in front of sprites
    // [2] : No sprite visible
    if (r_spr_vis_p3 >= r_PF1P)
      r_spr_vis_p5[0] <= 1'b1;
    else
      r_spr_vis_p5[0] <= 1'b0;
    if (r_spr_vis_p3 >= r_PF2P)
      r_spr_vis_p5[1] <= 1'b1;
    else
      r_spr_vis_p5[1] <= 1'b0;
    r_spr_vis_p5[2] <= r_spr_vis_p3[2];
  end
end

reg [3:0] r_ham_clut_p5;
reg [5:0] r_bpl_clut_p6;
reg [5:0] r_clut_idx_p6;
reg       r_spr_sel_p6;

// Sprites-playfields priority logic
always@(posedge clk) begin
  if (cck_edge | cckq_edge) begin    
    // Sprites/playfields test
    if (((r_spr_vis_p5[0]) && (r_pf_vld_p5[0])) || // Playfield #1 test
        ((r_spr_vis_p5[1]) && (r_pf_vld_p5[1])))   // Playfield #2 test
    begin
      // Playfields in front of sprites
      r_clut_idx_p6 <= r_HOMOD ? { 2'b0, r_bpl_clut_p5[3:0] }: r_bpl_clut_p5;
      // Select playfields
      r_spr_sel_p6 <= 1'b0;
    end else begin
      // Sprites in front of playfields
      if (r_spr_vis_p5[2]) begin
        // No sprite visible : show playfields
        r_clut_idx_p6 <= r_HOMOD ? { 2'b0, r_bpl_clut_p5[3:0] }: r_bpl_clut_p5;
        // Select playfields
        r_spr_sel_p6 <= 1'b0;
      end
      else begin
        // Sprites visible
        r_clut_idx_p6 <= { 2'b01, r_spr_clut_p5 };
        // Select sprites
        r_spr_sel_p6 <= 1'b1;
      end
    end
  end
end

///////////////////////////////////////
// Color look-up table instantiation //
///////////////////////////////////////

wire        w_cpu_wr;
wire        w_clut_rd;
wire [11:0] w_clut_rgb_p7;

// Color look-up table write strobe
//assign w_cpu_wr = w_wregs_clut_p1 & cck_edge & cck;
// Half a CDAC_n cycle earlier for the Copper to be in sync.
assign w_cpu_wr = w_wregs_clut_p1 & cckq_edge & ~cck;

// Color look-up table read strobe
assign w_clut_rd = cck_edge | cckq_edge | cdac_edge;

ColourTable U_color_table
(
  .clk(clk),
  .cpu_wr(w_cpu_wr),
  .cpu_idx(r_rga_p1[5:1]),
  .cpu_rgb(db_in[11:0]),

  .clut_rd(w_clut_rd),
  .clut_idx(r_clut_idx_p6[4:0]),
  .clut_rgb(w_clut_rgb_p7)
); 

////////////////////////////
// Mask RGB with blanking //
////////////////////////////

reg [11:0] r_rgb_p9;
reg [11:0] r_rgb_p10;
reg        r_blank_n_p9;
reg        r_blank_n_p10;

always@(posedge clk) begin
  if (w_pixel_clk) begin

    if (r_cblank_p4) begin
        r_rgb_p9 <= 12'h000;

    // end else if (r_spr_sel_p6) begin
    //     r_rgb_p10 <= w_clut_rgb_p7;

    end else if (r_HOMOD) begin
        // Hold and modify mode
        case (r_bpl_clut_p5[5:4])
            2'b00 : r_rgb_p9       <= w_clut_rgb_p7;      // Select color
            2'b01 : r_rgb_p9[3:0]  <= r_bpl_clut_p5[3:0]; // Modify blue
            2'b10 : r_rgb_p9[11:8] <= r_bpl_clut_p5[3:0]; // Modify red
            2'b11 : r_rgb_p9[7:4]  <= r_bpl_clut_p5[3:0]; // Modify green
        endcase
        // r_rgb_p10 <= r_rgb_p9;

    end else if (r_clut_idx_p6[5]) begin
        // Extra-half-brite
        r_rgb_p9 <= {
            1'b0, w_clut_rgb_p7[11:9], 
            1'b0, w_clut_rgb_p7[7:5], 
            1'b0, w_clut_rgb_p7[3:1] };

    end else begin
        // Regular colour
        r_rgb_p9 <= w_clut_rgb_p7;
    end

    if (r_spr_sel_p6) begin
      r_rgb_p10 <= w_clut_rgb_p7;

    end else begin
      r_rgb_p10 <= r_rgb_p9;

    end

    r_blank_n_p9  <= ~r_cblank_p4;
    r_blank_n_p10 <= r_blank_n_p9;
  end
end

// RGB output
assign red     = r_rgb_p10[11:8];
assign green   = r_rgb_p10[7:4];
assign blue    = r_rgb_p10[3:0];
assign blank_n = r_blank_n_p10;

endmodule
