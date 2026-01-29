// Copyright 2011, 2012 Frederic Requin
// Copyright 2024, 2025 Renee Cousins, The Buffee project, Inc
//  
// See README.md for details

module Denise (
    // Main clock
    input clk,        // Master clock (28/56/85 MHz)
    // Generated clocks
    input cck,        // CCK clock
    input cckq,       // CCK quadrature clock
    input cck_edge,   // CCK edge
    input cckq_edge,  // CCKQ edge
    input cdac_edge,  // CDAC edge

    // Mouse/Joystick
    input m0h,
    input m0v,
    input m1h,
    input m1v,

    // Configuration
    input cfg_ecs,  // OCS(0) or ECS(1) chipset
    input cfg_a1k,  // Normal mode(0), A1000 mode(1)

    // Busses
    input  [ 8:1] rga,     // RGA bus
    input  [15:0] db_in,   // Data bus input
    output [15:0] db_out,  // Data bus output
    output        db_oen,  // Data bus output enable

    // Video output
    output     [3:0] red,      // Red component output
    output     [3:0] green,    // Green component output
    output     [3:0] blue,     // Blue component output
    output reg       vsync,    // Vertical synchro
    output           blank_n,  // Composite blanking
    output reg       sol,      // Start of line (HPOS = 32)
    output           pal_ntsc  // PAL (1), NSTC (0) flag
);

  ///////////////////////////////
  // Register address decoding //
  ///////////////////////////////

  reg [8:1] r_rga_p1;
  always @(posedge clk) begin
    if (cck_edge & cck) begin
      // Latch RGA bits for next cycle
      r_rga_p1 <= rga;  //[5:1];
    end
  end

  // Comparators
  wire w_rregs_joy0_p1 = (r_rga_p1[8:1] == 8'b0_0000_101);  // JOYxDAT  : $00A
  wire w_rregs_joy1_p1 = (r_rga_p1[8:1] == 8'b0_0000_110);  // JOYxDAT  : $00C
  wire w_rregs_clx_p1 =  (r_rga_p1[8:1] == 8'b0_0000_111);  // CLXDAT   : $00E
  wire w_rregs_id_p1 =   (r_rga_p1[8:1] == 8'b0_0111_110);  // DENISEID : $07C

  wire w_wregs_joyw_p1 = (r_rga_p1[8:1] == 8'b0_0011_011);  // JOYTEST  : $036
  wire w_wregs_str_p1 =  (r_rga_p1[8:1] == 8'b0_0011_1xx);  // Strobes  : $038 - $03E
  wire w_wregs_diwb_p1 = (r_rga_p1[8:1] == 8'b0_1000_111);  // DIWSTRT  : $08E
  wire w_wregs_diwe_p1 = (r_rga_p1[8:1] == 8'b0_1001_000);  // DIWSTOP  : $090
  wire w_wregs_clx_p1 =  (r_rga_p1[8:1] == 8'b0_1001_100);  // CLXCON   : $098
  wire w_wregs_ctl_p1 =  (r_rga_p1[8:1] == 8'b1_0000_0xx);  // BPLCONx  : $100 - $106
  wire w_wregs_bpl_p1 =  (r_rga_p1[8:1] == 8'b1_0001_xxx);  // BPLxDAT  : $110 - $11E
  wire w_wregs_spr_p1 =  (r_rga_p1[8:1] == 8'b1_01xx_xxx);  // Sprites  : $140 - $17E
  wire w_wregs_clut_p1 = (r_rga_p1[8:1] == 8'b1_10xx_xxx);  // Color    : $180 - $1BE
  wire w_wregs_diwh_p1 = (r_rga_p1[8:1] == 8'b1_1110_010);  // DIWHIGH  : $1E4

  wire [15:0] jm_db_out;
  wire [15:0] clx_db_out;
  wire        w_denise_id = w_rregs_id_p1 && cfg_ecs;

  assign db_out = jm_db_out | clx_db_out | (w_denise_id ? 16'hFFFC : 16'd0);
  assign db_oen = w_rregs_clx_p1 | w_rregs_joy0_p1 | w_rregs_joy1_p1 | w_denise_id;

  // Implement Joystick & Mouse decoder
  JoyMouse joymouse (
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

  wire [5:0] bpl_data = w_bpl_pixel_bus[5:0];
  // wire [1:0] spr_data [0:7];
  // reg [1:0] r_spr_pix_p2 [0:7];

  // Pack sprite data
  // wire [15:0] spr_data_flat = {
  //   spr_data[7],spr_data[6],spr_data[5],spr_data[4],
  //   spr_data[3],spr_data[2],spr_data[1],spr_data[0] };
  wire [15:0] spr_data_flat = {
    r_spr_pix_p2[7],
    r_spr_pix_p2[6],
    r_spr_pix_p2[5],
    r_spr_pix_p2[4],
    r_spr_pix_p2[3],
    r_spr_pix_p2[2],
    r_spr_pix_p2[1],
    r_spr_pix_p2[0]
  };

  // Implement Collision
  Collision collision (
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

  always @(posedge clk) begin
    if (cck_edge & cck) begin
      if (w_wregs_str_p1) begin
        // STRLONG strobes reset the counter
        if (r_rga_p1[2:1] == 2'b11) r_str_ctr <= 2'b00;
        else if (r_str_ctr != 2'b11) r_str_ctr <= r_str_ctr + 2'd1;
      end
    end
  end

  assign pal_ntsc = &r_str_ctr;

  //////////////////////
  // Vertical synchro //
  //////////////////////

  reg [3:0] r_equ_ctr;

  always @(posedge clk) begin
    if (cck_edge & cck) begin
      if (w_wregs_str_p1) begin
        // Discard STRLONG strobes
        if (r_rga_p1[2:1] != 2'b11) begin
          // STREQU strobes increment counter
          if (r_rga_p1[2:1] == 2'b00) r_equ_ctr <= r_equ_ctr + 4'd1;
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

  wire       w_hpos_clr;
  wire       w_hpos_dis;
  reg  [8:0] r_hpos;
  reg        r_lol_ena;

  // HPOS clear conditions
  assign w_hpos_clr = (((r_rga_p1[2:1] == 2'b00) && (cfg_ecs)) || 
                        (r_rga_p1[2:1] == 2'b01) ||
                        (r_rga_p1[2:1] == 2'b10)) ? (w_wregs_str_p1 & cck) : 1'b0;
  // HPOS disable conditions
  assign w_hpos_dis = (r_rga_p1[2:1] == 2'b11) ? (w_wregs_str_p1 & cck) : 1'b0;

  always @(posedge clk) begin
    if (cck_edge) begin
      if (w_hpos_clr) begin
        // STREQU (ECS only), STRVBL or STRHOR : HPOS starts at 2
        r_hpos    <= 9'h1fe;
        r_lol_ena <= 1'b0;
      end else begin
        // STRLONG : long line, disable HPOS counting during 1 clock cycle
        if (w_hpos_dis) r_lol_ena <= 1'b1;
        else r_hpos <= r_hpos + 9'd1;
      end
    end
    // Start of line flag for external scandoubler
    if (r_hpos == 9'd32)
      if (cckq_edge) sol <= 1'b1;
      else if (cck_edge) sol <= 1'b0;
  end

  ///////////////////////////////
  // Horizontal display window //
  ///////////////////////////////

  reg [8:0] r_HDIWSTRT;
  reg [8:0] r_HDIWSTOP;
  reg       r_hwin_ena;
  // reg       r_hwin_ena_p1;
  reg       r_hwin_ena_p2;
  reg       r_vwin_ena;

  always @(posedge clk) begin
    if (cck_edge & cck) begin
      // DIWSTRT
      if (w_wregs_diwb_p1) r_HDIWSTRT <= {1'b0, db_in[7:0]};
      // DIWSTOP
      if (w_wregs_diwe_p1) r_HDIWSTOP <= {1'b1, db_in[7:0]};
      // DIWHIGH
      if ((w_wregs_diwh_p1) && (cfg_ecs)) begin
        r_HDIWSTRT[8] <= db_in[5];
        r_HDIWSTOP[8] <= db_in[13];
      end
    end
  end

  always @(posedge clk) begin
    if (cckq_edge) begin
      // Display window horizontal start
      if (r_hpos == r_HDIWSTRT) r_hwin_ena_p2 <= r_vwin_ena;  //1'b1;
      // Display window horizontal stop
      else if (r_hpos == r_HDIWSTOP) r_hwin_ena_p2 <= 1'b0;

      // Vertical window
      if (r_hpos == 9'h013) r_vwin_ena <= 1'b0;
      else if (w_wregs_bpl_p1) r_vwin_ena <= 1'b1;

      // Delayed horizontal + vertical window
      // r_hwin_ena_p2 <= r_hwin_ena & r_vwin_ena;
      // r_hwin_ena_p2 <= r_hwin_ena_p1;
    end
  end

  ///////////////////////
  // Vertical blanking //
  ///////////////////////

  reg r_vblank_p2;

  always @(posedge clk) begin
    if (cck_edge & cck) begin
      // Vertical blanking only during STREQU and STRVBL
      if ((w_wregs_str_p1) && (r_rga_p1[2:1] != 2'b11)) r_vblank_p2 <= ~r_rga_p1[2];
    end
  end

  /////////////////////////
  // Horizontal blanking //
  /////////////////////////

  reg r_hblank_p3;

  always @(posedge clk) begin
    //if (cckq_edge) begin
    //  r_hblank_p3 <= ~r_hwin_ena_p2;
    //end
    if (cck_edge) begin
      if (r_hpos == 9'h013) r_hblank_p3 <= 1'b1;
      else if (r_hpos == 9'h061) r_hblank_p3 <= 1'b0;
    end
  end

  ////////////////////////
  // Composite blanking //
  ////////////////////////

  reg r_cblank_p4;

  // (BUG!! but implemented this way on real HW)
  always @(posedge clk) begin
    if (cckq_edge) begin
      r_cblank_p4 <= r_hblank_p3 | r_vblank_p2;
    end
  end


  ////////////////////////////////
  // Bitplane Control registers //
  ////////////////////////////////

  reg       r_HIRES;
  reg       r_SHRES;
  reg [2:0] r_BPU;
  reg       r_HOMOD;
  reg       r_DBLPF;

  // BPLCON0 register
  always @(posedge clk) begin
    if (cck_edge & cck) begin
      if ((w_wregs_ctl_p1) && (r_rga_p1[2:1] == 2'b00)) begin
        r_HIRES <= db_in[15];
        r_BPU   <= db_in[14:12];
        r_HOMOD <= db_in[11];
        r_DBLPF <= db_in[10];
        r_SHRES <= db_in[6] && cfg_ecs;
      end
    end
  end

  reg [3:0] r_PF1H;
  reg [3:0] r_PF2H;

  // BPLCON1 register
  always @(posedge clk) begin
    if (cck_edge & cck) begin
      if ((w_wregs_ctl_p1) && (r_rga_p1[2:1] == 2'b01)) begin
        r_PF1H <= db_in[3:0];
        r_PF2H <= db_in[7:4];
      end
    end
  end

  reg       r_PF2PRI;
  reg [2:0] r_PF2P;
  reg [2:0] r_PF1P;

  // BPLCON2 register
  always @(posedge clk) begin
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
  always @(posedge clk) begin
    if (cck_edge & cck) begin
      // Bitplane enable flags updated during BPL1DAT write
      if ((w_wregs_bpl_p1) && (r_rga_p1[3:1] == 3'b000)) begin
        case (r_BPU)
          3'd0: r_bpl_ena <= 8'b00000000;
          3'd1: r_bpl_ena <= 8'b00000001;
          3'd2: r_bpl_ena <= 8'b00000011;
          3'd3: r_bpl_ena <= 8'b00000111;
          3'd4: r_bpl_ena <= 8'b00001111;
          3'd5: r_bpl_ena <= 8'b00011111;
          3'd6: r_bpl_ena <= 8'b00111111;
          3'd7: r_bpl_ena <= 8'b01111111;
        endcase
      end
    end
  end


  //                                                                                    
  //    88888888ba   88                                                    ,a8888a,     
  //    88      "8b  88                                                  ,8P"'  `"Y8,   
  //    88      ,8P  88                                                 ,8P        Y8,  
  //    88aaaaaa8P'  88,dPPYba,   ,adPPYYba,  ,adPPYba,   ,adPPYba,     88          88  
  //    88""""""'    88P'    "8a  ""     `Y8  I8[    ""  a8P_____88     88          88  
  //    88           88       88  ,adPPPPP88   `"Y8ba,   8PP"""""""     `8b        d8'  
  //    88           88       88  88,    ,88  aa    ]8I  "8b,   ,aa      `8ba,  ,ad8'   
  //    88           88       88  `"8bbdP"Y8  `"YbbdP"'   `"Ybbd8"'        "Y8888P"     
  //                                                                                    
  //                                                                                    
  //  Load registers and indicate when ready

  //  Bitplanes Data

  reg [15:0] r_BPLxDAT  [0:7];
  reg        r_bpl_load;
  reg [ 3:0] r_ddf_dly;

  always @(posedge clk) begin
    if (cck_edge && cck) begin
      // Trigger loading of second stage registers
      r_bpl_load <= w_wregs_bpl_p1 && (r_rga_p1[3:1] == 3'b000);
      if (w_wregs_bpl_p1) begin
        // Load BPLxDAT register
        r_BPLxDAT[r_rga_p1[3:1]] <= db_in[15:0];
        // BPL1DAT is written : 
        // if (r_rga_p1[3:1] == 3'b000) begin
        //   // Non-aligned DDFSTRT delay
        //   r_ddf_dly[3] <= r_hpos[3] & ~(r_HIRES | r_SHRES);
        //   r_ddf_dly[2] <= r_hpos[2] & ~r_SHRES;
        //   r_ddf_dly[1] <= r_hpos[1];
        //   r_ddf_dly[0] <= 1'b0;
        // end
      end
    end
  end

  // Sprites data and positions

  reg        r_SPRATT [0:7];
  reg [ 8:0] r_SPRHPOS[0:7];
  reg [15:0] r_SPRDATA[0:7];
  reg [15:0] r_SPRDATB[0:7];

  reg        r_armed  [0:7];

  // SPRxPOS,  SPRxCTL, SPRxDATA and SPRxDATB registers
  always @(posedge clk) begin
    if (cck_edge) begin
      if ((w_wregs_spr_p1) && (cck)) begin
        case (r_rga_p1[2:1])
          2'b00 : // SPRxPOS register
          begin
            r_SPRHPOS[r_rga_p1[5:3]][8:1] <= db_in[7:0];
          end
          2'b01 : // SPRxCTL register
          begin
            r_SPRATT[r_rga_p1[5:3]]     <= db_in[7];
            r_SPRHPOS[r_rga_p1[5:3]][0] <= db_in[0];
            r_armed[r_rga_p1[5:3]]      <= 1'b0;  // Sprite disabled
          end
          2'b10 : // SPRxDATA register
          begin
            r_SPRDATA[r_rga_p1[5:3]] <= db_in[15:0];
            r_armed[r_rga_p1[5:3]]   <= 1'b1;  // Sprite enabled
          end
          2'b11 : // SPRxDATB register
          begin
            r_SPRDATB[r_rga_p1[5:3]] <= db_in[15:0];
          end
        endcase
      end
    end
  end

  //                                                                            
  //    88888888ba   88                                                     88  
  //    88      "8b  88                                                   ,d88  
  //    88      ,8P  88                                                 888888  
  //    88aaaaaa8P'  88,dPPYba,   ,adPPYYba,  ,adPPYba,   ,adPPYba,         88  
  //    88""""""'    88P'    "8a  ""     `Y8  I8[    ""  a8P_____88         88  
  //    88           88       88  ,adPPPPP88   `"Y8ba,   8PP"""""""         88  
  //    88           88       88  88,    ,88  aa    ]8I  "8b,   ,aa         88  
  //    88           88       88  `"8bbdP"Y8  `"YbbdP"'   `"Ybbd8"'         88  
  //                                                                            
  //                                                                            

  //  Latch into the shift registers on CCK
  //  Otherwise shift out at pixel clock (BPL) or CCK (SPR)

  wire w_pixel_clk = (cck_edge) || (cckq_edge && (r_HIRES || r_SHRES)) || (cdac_edge && r_SHRES);
  integer i;

  // Bitplane shifters
  reg [15:0] r_bpl_shift[0:7];
  reg [15:0] r_bpl_delay[0:7];

  always @(posedge clk) begin
    if (cck_edge && cck && r_bpl_load) begin
      for (i = 0; i < 8; i = i + 1) begin
        r_bpl_shift[i] <= r_BPLxDAT[i];
      end
    end else if (w_pixel_clk) begin
      for (i = 0; i < 8; i = i + 1) begin
        r_bpl_shift[i] <= {r_bpl_shift[i][14:0], 1'b0};
      end
    end

    if (w_pixel_clk) begin
      for (i = 0; i < 8; i = i + 1) begin
        r_bpl_delay[i] <= {r_bpl_delay[i][14:0], r_bpl_shift[i][15]};
      end
    end
  end

  // Data out to priority & clut
  wire [7:0] w_bpl_pixel_bus = {
    r_bpl_delay[7][r_PF2H], r_bpl_delay[6][r_PF1H],
    r_bpl_delay[5][r_PF2H], r_bpl_delay[4][r_PF1H],
    r_bpl_delay[3][r_PF2H], r_bpl_delay[2][r_PF1H],
    r_bpl_delay[1][r_PF2H], r_bpl_delay[0][r_PF1H]
  } & r_bpl_ena & {8{r_hwin_ena_p2}};

  // 140 ns delay for NTSC long lines

  reg  [7:0] r_pf_lol_1;
  reg  [7:0] r_pf_lol_2;
  reg  [7:0] r_pf_lol_3;
  reg  [7:0] r_pf_lol_4;
  reg  [7:0] r_pf_lol_5;
  reg  [7:0] r_pf_lol_6;
  reg  [7:0] r_pf_lol_7;
  reg  [7:0] r_pf_lol_8;
  
  always @(posedge clk) begin
    if (w_pixel_clk) begin
      r_pf_lol_1 <= w_bpl_pixel_bus;
      r_pf_lol_2 <= r_pf_lol_1;
      r_pf_lol_3 <= r_pf_lol_2;
      r_pf_lol_4 <= r_pf_lol_3;
      r_pf_lol_5 <= r_pf_lol_4;
      r_pf_lol_6 <= r_pf_lol_5;
      r_pf_lol_7 <= r_pf_lol_6;
      r_pf_lol_8 <= r_pf_lol_7;
    end
  end

  wire [7:0] w_bpl_data = (!r_lol_ena) ? w_bpl_pixel_bus : r_SHRES ? r_pf_lol_8 : r_HIRES ? r_pf_lol_4 : r_pf_lol_2;

  // Sprite shifters
  reg [15:0] r_spr_shift_A[0:7];
  reg [15:0] r_spr_shift_B[0:7];

  always @(posedge clk) begin
    if (cck_edge) begin
      // Sprites shift registers
      for (i = 0; i < 8; i = i + 1) begin
        if ((r_hpos == r_SPRHPOS[i]) && r_armed[i]) begin
          r_spr_shift_A[i] <= r_SPRDATA[i];
          r_spr_shift_B[i] <= r_SPRDATB[i];
        end else begin
          r_spr_shift_A[i] <= {r_spr_shift_A[i][14:0], 1'b0};
          r_spr_shift_B[i] <= {r_spr_shift_B[i][14:0], 1'b0};
        end
      end
    end
  end

  // Data out to priority & clut
  wire [15:0] w_spr_pixel_bus = {
    r_spr_shift_A[0][15], r_spr_shift_B[0][15], r_spr_shift_A[1][15], r_spr_shift_B[1][15], 
    r_spr_shift_A[2][15], r_spr_shift_B[2][15], r_spr_shift_A[3][15], r_spr_shift_B[3][15], 
    r_spr_shift_A[4][15], r_spr_shift_B[4][15], r_spr_shift_A[5][15], r_spr_shift_B[5][15], 
    r_spr_shift_A[6][15], r_spr_shift_B[6][15], r_spr_shift_A[7][15], r_spr_shift_B[7][15]
  };

  // Phase 2 -- bpl/spr colour determination
  // Phase 3 -- colour look up table
  // Phase 4 -- final pixel blending (HAM & EHB)


  //                                                                                 
  //    88888888ba   88                                                  ad888888b,  
  //    88      "8b  88                                                 d8"     "88  
  //    88      ,8P  88                                                         a8P  
  //    88aaaaaa8P'  88,dPPYba,   ,adPPYYba,  ,adPPYba,   ,adPPYba,          ,d8P"   
  //    88""""""'    88P'    "8a  ""     `Y8  I8[    ""  a8P_____88        a8P"      
  //    88           88       88  ,adPPPPP88   `"Y8ba,   8PP"""""""      a8P'        
  //    88           88       88  88,    ,88  aa    ]8I  "8b,   ,aa     d8"          
  //    88           88       88  `"8bbdP"Y8  `"YbbdP"'   `"Ybbd8"'     88888888888  
  //                                                                                 
  //                                                                                 

  // From here, both bitplanes and sprites should be clocked the same

  // wire  [7:0] w_bpl_pixel_bus
  // wire [15:0] w_spr_pixel_bus

  // Playfields

  reg [5:0] r_pf_data_p2;
  reg [1:0] r_pf_vld_p2;

  // this is the important output from this phase
  reg [5:0] r_bpl_clut_p2;

  always @(posedge clk) begin
    if (w_pixel_clk) begin
      // Masked playfields data
      r_pf_data_p2[0] = w_bpl_pixel_bus[0];
      r_pf_data_p2[1] = w_bpl_pixel_bus[1];
      r_pf_data_p2[2] = w_bpl_pixel_bus[2];
      r_pf_data_p2[3] = w_bpl_pixel_bus[3];
      r_pf_data_p2[4] = w_bpl_pixel_bus[4];
      r_pf_data_p2[5] = w_bpl_pixel_bus[5];

      // Playfields valid signal
      if (r_DBLPF) begin
        // Dual playfield mode
        r_pf_vld_p2[0] = r_pf_data_p2[0] | r_pf_data_p2[2] | r_pf_data_p2[4];
        r_pf_vld_p2[1] = r_pf_data_p2[1] | r_pf_data_p2[3] | r_pf_data_p2[5];
      end else begin
        // Single playfield mode
        r_pf_vld_p2[0] = 1'b0;
        r_pf_vld_p2[1] = |r_pf_data_p2;
      end

      // Playfields 1 & 2 priority logic
      if (r_DBLPF) begin
        // Dual playfield mode
        if (r_PF2PRI) begin
          // PF2 has priority
          case (r_pf_vld_p2)
            2'b00:   r_bpl_clut_p2 <= 6'b000000;
            2'b01:   r_bpl_clut_p2 <= {3'b000, r_pf_data_p2[4], r_pf_data_p2[2], r_pf_data_p2[0]};
            default: r_bpl_clut_p2 <= {3'b001, r_pf_data_p2[5], r_pf_data_p2[3], r_pf_data_p2[1]};
          endcase
        end else begin
          // PF1 has priority
          case (r_pf_vld_p2)
            2'b00:   r_bpl_clut_p2 <= 6'b000000;
            2'b10:   r_bpl_clut_p2 <= {3'b001, r_pf_data_p2[5], r_pf_data_p2[3], r_pf_data_p2[1]};
            default: r_bpl_clut_p2 <= {3'b000, r_pf_data_p2[4], r_pf_data_p2[2], r_pf_data_p2[0]};
          endcase
        end
      end else begin
        // Single playfield mode

        // OCS/ECS undocumented behaviour
        // PF2P > 5 (BPLCON2) and BITPLANES == 5 and NOT AGA
        // - pixel in bitplane 5 = zero: planes 1-4 work normally (any color from 0-15 is possible)
        // - pixel in bitplane 5 = one: planes 1-4 are disabled, only pixel from plane 5 is shown (color 16 is visible)
        if ((r_PF2P[2:1] == 2'b11) && (r_BPU == 4'd5) && (r_pf_data_p2[4]))
          r_bpl_clut_p2 <= 6'b010000;
        else
          // Normal behaviour
          r_bpl_clut_p2 <= r_pf_data_p2;
      end
    end
  end

  // Sprites

  reg [1:0] r_spr_pix_p2 [0:7];
  reg [3:0] r_spr_grp;
  reg [2:0] r_spr_grp_vis_p2;
  reg [2:0] r_idx_e_p2;
  reg [2:0] r_idx_o_p2;
  reg       r_spr_att_p2;
  reg [1:0] r_spr_odd_p2;
  reg [1:0] r_spr_even_p2;
  reg [2:0] r_spr_bdr_vis_p2;

  // Meaningful outputs
  reg [3:0] r_spr_clut_p2;

  // Sprites pixels and groups
  always @(posedge clk) begin
    if (w_pixel_clk) begin

      // Sprites pixels values (shift registers outputs)
      for (i = 0; i < 8; i = i + 1) begin
        r_spr_pix_p2[i][0] = r_spr_shift_A[i][15];
        r_spr_pix_p2[i][1] = r_spr_shift_B[i][15];
      end

      // Sprites #0 and #1 => group #0
      // FIXME this is also used for groups
      r_spr_grp[0] = ((r_spr_shift_A[0][15] | r_spr_shift_B[0][15]))
                   | ((r_spr_shift_A[1][15] | r_spr_shift_B[1][15]));
      // Sprites #2 and #3 => group #1
      r_spr_grp[1] = ((r_spr_shift_A[2][15] | r_spr_shift_B[2][15]))
                   | ((r_spr_shift_A[3][15] | r_spr_shift_B[3][15]));
      // Sprites #4 and #5 => group #2
      r_spr_grp[2] = ((r_spr_shift_A[4][15] | r_spr_shift_B[4][15]))
                   | ((r_spr_shift_A[5][15] | r_spr_shift_B[5][15]));
      // Sprites #6 and #7 => group #3
      r_spr_grp[3] = ((r_spr_shift_A[6][15] | r_spr_shift_B[6][15]))
                   | ((r_spr_shift_A[7][15] | r_spr_shift_B[7][15]));
                   
      // Visible group number
      case (r_spr_grp)
        4'b0000: r_spr_grp_vis_p2 = 3'd7;  // No sprite visible
        4'bxxx1: r_spr_grp_vis_p2 = 3'd0;  // Sprite #0 or #1 visible
        4'bxx10: r_spr_grp_vis_p2 = 3'd1;  // Sprite #2 or #3 visible
        4'bx100: r_spr_grp_vis_p2 = 3'd2;  // Sprite #4 or #5 visible
        4'b1000: r_spr_grp_vis_p2 = 3'd3;  // Sprite #6 or #7 visible
        default: ;
      endcase

      // Sprites indexes
      r_idx_e_p2 = {r_spr_grp_vis_p2[1:0], 1'b0};  // Even (0, 2, 4 ,6)
      r_idx_o_p2 = {r_spr_grp_vis_p2[1:0], 1'b1};  // Odd (1, 3, 5, 7)

      // Sprite attached flag
      r_spr_att_p2 = r_SPRATT[r_idx_o_p2] | (r_SPRATT[r_idx_e_p2] & cfg_ecs);

      // Odd and even sprites
      r_spr_odd_p2  = r_spr_pix_p2[r_idx_o_p2];
      r_spr_even_p2 = r_spr_pix_p2[r_idx_e_p2];

      // Visible sprite index (masked by the horizontal window)
      r_spr_bdr_vis_p2  <= r_spr_grp_vis_p2 | {3{~r_hwin_ena_p2}};

      if (r_spr_att_p2)
        // Attached mode : 15-color sprite
        r_spr_clut_p2 <= { r_spr_odd_p2, r_spr_even_p2 };
      else if (r_spr_even_p2 != 2'b00)
        // Show even sprite with 3 colors
        r_spr_clut_p2 <= { r_spr_grp_vis_p2[1:0], r_spr_even_p2 };
      else
        // Show odd sprite with 3 colors
        r_spr_clut_p2 <= { r_spr_grp_vis_p2[1:0], r_spr_odd_p2 };

    end
  end


  //                                                                                 
  //    88888888ba   88                                                  ad888888b,  
  //    88      "8b  88                                                 d8"     "88  
  //    88      ,8P  88                                                         a8P  
  //    88aaaaaa8P'  88,dPPYba,   ,adPPYYba,  ,adPPYba,   ,adPPYba,          aad8"   
  //    88""""""'    88P'    "8a  ""     `Y8  I8[    ""  a8P_____88          ""Y8,   
  //    88           88       88  ,adPPPPP88   `"Y8ba,   8PP"""""""             "8b  
  //    88           88       88  88,    ,88  aa    ]8I  "8b,   ,aa     Y8,     a88  
  //    88           88       88  `"8bbdP"Y8  `"YbbdP"'   `"Ybbd8"'      "Y888888P'  
  //                                                                                 
  //                                                                                 

  // Colour look up tables
  reg  [11:0] r_bpl_rgb_p3;
  reg  [11:0] r_spr_rgb_p3;
  
  // Infered block RAM
  reg  [11:0] r_mem_clut_a [0:31];
  reg  [11:0] r_mem_clut_b [0:31];

  // Write port
  always@(posedge clk) begin
    if (w_wregs_clut_p1 & cck_edge & cck) begin
      r_mem_clut_a[r_rga_p1[5:1]] <= db_in[11:0];
      r_mem_clut_b[r_rga_p1[5:1]] <= db_in[11:0];
    end
  end

  reg  [2:0] r_spr_vis_p3;
  reg        r_spr_sel_p3;

  always@(posedge clk) begin
    if (w_pixel_clk) begin
      // Read bitplane colour
      if (r_HOMOD) begin
        case (r_bpl_clut_p2[5:4])
          2'b00: r_bpl_rgb_p3       <= r_mem_clut_a[{ 1'b0, r_bpl_clut_p2[3:0]}]; // Select color
          2'b01: r_bpl_rgb_p3[3:0]  <=                      r_bpl_clut_p2[3:0];   // Modify blue
          2'b10: r_bpl_rgb_p3[11:8] <=                      r_bpl_clut_p2[3:0];   // Modify red
          2'b11: r_bpl_rgb_p3[7:4]  <=                      r_bpl_clut_p2[3:0];   // Modify green
        endcase
      end
      else if (r_bpl_clut_p2[5])
        r_bpl_rgb_p3 <= { 1'b0, r_mem_clut_a[r_bpl_clut_p2[4:0]][11:1] & 11'b11101110111 };
      else
        r_bpl_rgb_p3 <= r_mem_clut_a[r_bpl_clut_p2[4:0]];

      // Read sprite colour
      r_spr_rgb_p3 <= r_mem_clut_b[{ 1'b1, r_spr_clut_p2[3:0] }];

      // Sprite visible flags
      // [0] : PF1 is in front of sprites
      // [1] : PF2 is in front of sprites
      // [2] : No sprite visible
      r_spr_vis_p3[0] = (r_spr_bdr_vis_p2 >= r_PF1P) ? 1'b1 : 1'b0;
      r_spr_vis_p3[1] = (r_spr_bdr_vis_p2 >= r_PF2P) ? 1'b1 : 1'b0;
      r_spr_vis_p3[2] =  r_spr_bdr_vis_p2[2];

      // Sprites/playfields test
      if (((r_spr_vis_p3[0]) && (r_pf_vld_p2[0]))  // Playfield #1 test
      ||  ((r_spr_vis_p3[1]) && (r_pf_vld_p2[1]))) // Playfield #2 test
      begin
        // Playfields in front of sprites
        r_spr_sel_p3 <= 1'b0;
      end else begin
        // Sprites in front of playfields
        if (r_spr_vis_p3[2]) begin
          // No sprite visible : show playfields
          r_spr_sel_p3 <= 1'b0;
        end else begin
          // Sprites visible
          r_spr_sel_p3 <= 1'b1;
        end
      end      
    end
  end

  //                                                                                   
  //    88888888ba   88                                                         ,d8    
  //    88      "8b  88                                                       ,d888    
  //    88      ,8P  88                                                     ,d8" 88    
  //    88aaaaaa8P'  88,dPPYba,   ,adPPYYba,  ,adPPYba,   ,adPPYba,       ,d8"   88    
  //    88""""""'    88P'    "8a  ""     `Y8  I8[    ""  a8P_____88     ,d8"     88    
  //    88           88       88  ,adPPPPP88   `"Y8ba,   8PP"""""""     8888888888888  
  //    88           88       88  88,    ,88  aa    ]8I  "8b,   ,aa              88    
  //    88           88       88  `"8bbdP"Y8  `"YbbdP"'   `"Ybbd8"'              88    
  //                                                                                   
  //       

  // Colour MUX

  reg [11:0] r_rgb_out;
  reg        r_blank_out;

  always @(posedge clk) begin
    if (w_pixel_clk) begin
      if (r_cblank_p4)        r_rgb_out <= 12'h000;
      else if (r_spr_sel_p3)  r_rgb_out <= r_spr_rgb_p3;
      else                    r_rgb_out <= r_bpl_rgb_p3;
    end
  end

  // RGB output
  assign red     = r_rgb_out[11:8];
  assign green   = r_rgb_out[7:4];
  assign blue    = r_rgb_out[3:0];
  assign blank_n = r_blank_out;

endmodule
