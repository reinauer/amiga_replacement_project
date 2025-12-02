//////////////////////////////////////////////////////////////////////////////////
// Company: The Buffee Project
// Engineer: Renee Cousins (renee.cousins@buffee.ca)
//
// Create Date:    13:13:40 03/07/2022
// Design Name:
// Module Name:    Denise_8373
// Project Name:   MiniMig 2
// Target Devices: Any
// Tool versions:  ISE13.4
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
// Initial source taken from the MCC-216 project
// Copyright 2011, 2012 Frederic Requin; part of the MCC216 project
//
//////////////////////////////////////////////////////////////////////////////////
//
// TODO
// - verify priority logic
//

module Denise_8373(
    // Standard Denise Signals
    //                             Pin        Used Active  Description
    inout      [15:0] DB,       // 1-7, 40-48       High    Data bus input
    input             M1H,      //  8               High    Mouse 1 horizontal
    input             M0H,      //  9               High    Mouse 0 horizontal
    input       [8:1] RGA,      // 10-17            High    RGA bus
    output           nBURST,    //  18         No   Low     Colour burst
    //                Vdd           19         No   Pwr     Common 5V supply
    output reg  [3:0] RED,      // 20-23            High    Red component output
    output reg  [3:0] GREEN,    // 24-27            High    Green component output
    output reg  [3:0] BLUE,     // 28-31            High    Blue component output   
    input            nCBL,      //  32         No   Low     Composite blanking
    output reg       nZD,       //  33              Low     Background indicator
    input            nCDAC,     //  34              Clk     7.1MHz Quadrature clock
    input             C7M,      //  35              Clk     7.1MHz Processor clock
    input            nCAS,      //  36              Clk     3.5MHz Colour clock
    //                Vss           37         No   Pwr     Common Ground
    input             M1V,      //  38              High    Mouse 1 vertical
    input             M0V       //  39              High    Mouse 0 vertical
);
 
    wire C14M = C7M ^ ~nCDAC;             // 14MHz
/*    _____       _____       _____       _____       _____       _____
    _/     \_____/     \_____/     \_____/     \_____/     \_____/     \     C7M (CPU Bus)   
    ____       _____       _____       _____       _____       _____
        \_____/     \_____/     \_____/     \_____/     \_____/     \___    nCDAC
    _______             ___________             ___________
           \___________/           \___________/           \___________/    nCAS (nC1, colour clock)
          
    11111000000111111000000111111000000111111000000111111000000111111000    nCDAC (Binary)
    11111111000000000000111111111111000000000000111111111111000000000000    nCAS (Binary)
     :     :     :     :     :     :     :     :     :     :     :     :
     11    10    01    00    11    10    01    00    11    10    01    00   Phase
      __    __    __    __    __    __    __    __    __    __    __
    _/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/     C14M (C7M ^ ~nCDAC)
           
*/
    genvar i;

    reg [15:0] r_DB_out;
    wire       r_DB_out_en;

    assign DB = r_DB_out_en ? r_DB_out : 16'hz;

    reg [10:0] r_HCOUNT;
    
    wire [5:0] w_BPLxDAT;
    wire [7:0] w_SPRxDATA;
    wire [7:0] w_SPRxDATB;
    wire [7:0] w_SPRxENA;
    wire [3:0] w_SPRxGROUP;
    wire [4:0] w_SPRxCOLOR      [0:7];
    wire [15:0] w_CLXDAT;
    
    reg [15:0] r_BPLxDAT        [0:5];
    reg [15:0] r_BPLxDAT_pixel  [0:5];
    reg [15:0] r_BPLxDAT_latch  [0:5];
    reg [15:0] r_SPRxDATA       [0:7];
    reg [15:0] r_SPRxDATB       [0:7];
    reg [15:0] r_SPRxDATA_latch [0:7];
    reg [15:0] r_SPRxDATB_latch [0:7];
    reg [15:0] r_SPRxCTL        [0:7];
    reg [15:0] r_SPRxPOS        [0:7];
    reg [15:0] r_BPLCON         [0:3];
    reg [15:0] r_JOY0DAT;
    reg [15:0] r_JOY1DAT;
    reg [15:0] r_CLXDAT;
    reg [15:0] r_CLXCON;

    // Wire bit plane data bus (even bit planes)
    for(i=0; i<6; i=i+2) assign w_BPLxDAT[i] = r_BPLxDAT_pixel[i][r_BPLCON[1][3:0]] & (i > r_BPLCON[0][14:12]);
    // Wire bit plane data bus (odd bit planes)
    for(i=1; i<6; i=i+2) assign w_BPLxDAT[i] = r_BPLxDAT_pixel[i][r_BPLCON[1][7:4]] & (i > r_BPLCON[0][14:12]);
    // Wire sprite bit plane data bus A
    for(i=0; i<8; i=i+1) assign w_SPRxDATA[i] = r_SPRxDATA_latch[i][15];
    // Wire sprite bit plane data bus B
    for(i=0; i<8; i=i+1) assign w_SPRxDATB[i] = r_SPRxDATB_latch[i][15];
    // If a sprite is enabled; disable attached sprite channels
    for(i=0; i<8; i=i+1) assign w_SPRxENA[i] = (w_SPRxDATA[i] | w_SPRxDATB[i]) & (r_SPRxCTL[i][7] ^ i[0]);
    // If a sprite group is enabled
    for(i=0; i<8; i=i+2) assign w_SPRxGROUP[i>>1] = w_SPRxENA[i] | w_SPRxENA[i+1];
    // The colour output for each sptrie
    for(i=0; i<8; i=i+1) assign w_SPRxCOLOR[i] = (r_SPRxCTL[i][7] && ((i & 1)==0))
        // Attached sprites
        ? { 1'b0, w_SPRxDATA[i+1], w_SPRxDATB[i+2], w_SPRxDATA[i], w_SPRxDATB[i] }
        // Group sub priority
        : { i[1], i[0], // Select colour range for sprite
            (w_SPRxENA[i+1] ? w_SPRxDATA[i+2] : w_SPRxDATA[i]) ,
            (w_SPRxENA[i+1] ? w_SPRxDATB[i+2] : w_SPRxDATB[i])
          };

    // Priority control logic
    wire [2:0] w_PFAxPRI = r_BPLCON[2][2:0];
    wire [2:0] w_PFBxPRI = r_BPLCON[2][5:3];
    wire       w_PFBxSWP = r_BPLCON[2][6]; 
    wire [7:0] w_PFAxENA = 1 << w_PFAxPRI; // 3 to 8 binary decoder
    wire [7:0] w_PFBxENA = 1 << w_PFBxPRI; // 3 to 8 binary decoder

    // 74x147 10 to 4 priority encoder; inputs
    wire [9:0] w_PRI_IN = {
        w_PFAxENA[0] | w_PFBxENA[0], w_SPRxENA[0] | w_SPRxENA[1],
        w_PFAxENA[1] | w_PFBxENA[1], w_SPRxENA[2] | w_SPRxENA[3],
        w_PFAxENA[2] | w_PFBxENA[2], w_SPRxENA[4] | w_SPRxENA[5],
        w_PFAxENA[3] | w_PFBxENA[3], w_SPRxENA[6] | w_SPRxENA[6],
        w_PFAxPRI[2] | w_PFAxPRI[2], 1'b0
    };
    // 74x147 10 to 4 priority encoder; outputs
    wire [3:0] w_PRI_OUT = (
        ~w_PRI_IN[0] ? 4'b0001 : // playfield match 000
        ~w_PRI_IN[1] ? 4'b0010 : // sprite group 0 (000/001)
        ~w_PRI_IN[2] ? 4'b0011 : // playfield match 001
        ~w_PRI_IN[3] ? 4'b0100 : // sprite group 1 (010/011)
        ~w_PRI_IN[4] ? 4'b0101 : // playfield match 010
        ~w_PRI_IN[5] ? 4'b0110 : // sprite group 2 (100/101)
        ~w_PRI_IN[6] ? 4'b0111 : // playfield match 011
        ~w_PRI_IN[7] ? 4'b1000 : // sprite group 3 (110/111)
        ~w_PRI_IN[8] ? 4'b1001 : // playfield match 100
                       4'b1111);

    wire [5:0] w_SPRxCOL = w_SPRxENA[w_PRI_OUT[2:1], 1'b0]
        ? w_SPRxCOLOR[w_PRI_OUT[2:1], 1'b0]
        ? w_SPRxCOLOR[w_PRI_OUT[2:1], 1'b1];

    wire w_PFAxTOP = w_PRI_OUT[3:1] == w_PFAxPRI;
    wire w_PFBxTOP = w_PRI_OUT[3:1] == w_PFBxPRI;
    wire w_BPLxPFA =  { 2'b00, w_BPLxDAT[4], w_BPLxDAT[2], w_BPLxDAT[0] };
    wire w_BPLxPFB =  { 2'b01, w_BPLxDAT[5], w_BPLxDAT[3], w_BPLxDAT[1] };

    wire [5:0] r_COLOR_SEL = 
        (!w_PRI_OUT[0])                        ? w_SPRxCOL : // Draw sprite
        (w_PFAxTOP & ~r_BPLCON[0][10])         ? w_BPLxDAT : // Draw PF1
        (w_PFAxTOP & ~(w_PFBxTOP & w_PFBxSWP)) ? w_BPLxPFA : // Draw PF1 in DPF
        (w_PFBxTOP)                            ? w_BPLxPFA : // Draw PF2 in DPF
                                               6'b000000;  // Draw background
    wire w_HAM = r_BPLCON[0][11];

    reg  [15:0] r_COLOR [0:31];
    reg  [15:0] r_COLOR_OUT;
    reg  [15:0] l_DB;
    reg  [7:0]  l_RGA;
    reg  r_SPRxSHIFT;
    reg  r_BPLxSHIFT;
    
    always @(posedge C14M) begin
        // Push the pixels
        if (w_HAM && (r_COLOR_SEL[5:4] == 2'b11)) GREEN = r_COLOR_SEL[3:0];
        else if (w_HAM && (r_COLOR_SEL[5:4] == 2'b11)) RED = r_COLOR_SEL[3:0];
        else if (w_HAM && (r_COLOR_SEL[5:4] == 2'b11)) BLUE = r_COLOR_SEL[3:0];
        else { nZD, RED, GREEN, BLUE } = r_COLOR[r_COLOR_SEL][11:0];

        // In OCS, background is just COLOR00
        nZD <= r_COLOR_SEL == 6'b000000;

        // Mouse quadrature
        // Note that the Amiga mouse is multiplexed on the CCK through an
        // 74LS157. 
        //              A    B
        //   CCK        Low  High
        // 1 Left Joy   Up   Left   M0V
        // 2 Left Joy   Down Right  M0H
        // 3 Right Joy  Up   Left   M1V
        // 4 Right Joy  Down Right  M1H
        //              V/H  VQ/HQ
        //
        // For compatibility, the signals should be brought into Denise
        // using a similar method.
        //
        // Counting up           Couting Down
        // V/H VQ/HQ  D1  D0     V/H VQ/HQ  D1  D0
        //  0    0     1   0      0    0     1   0
        //  1    0     1   1      0    1     0   1
        //  1    1     0   0      1    1     0   0
        //  0    1     0   1      1    0     1   1
        //
        if(nCAS) begin // D1
            r_JOY0DAT[9] <= ~M0V;
            if((r_JOY0DAT[9:8] == 2'b11) & M0V) 
                r_JOY0DAT[15:10] <= r_JOY0DAT[15:10] + 1;
            if((r_JOY0DAT[9:8] == 2'b00) & ~M0V) 
                r_JOY0DAT[15:10] <= r_JOY0DAT[15:10] - 1;
                
            r_JOY0DAT[1] <= ~M0H;
            if((r_JOY0DAT[1:0] == 2'b11) & M0H) 
                r_JOY0DAT[7:2] <= r_JOY0DAT[7:2] + 1;
            if((r_JOY0DAT[1:0] == 2'b00) & ~M0H) 
                r_JOY0DAT[7:2] <= r_JOY0DAT[7:2] - 1;
                
            r_JOY1DAT[9] <= ~M1V;
            if((r_JOY1DAT[9:8] == 2'b11) & M1V) 
                r_JOY1DAT[15:10] <= r_JOY1DAT[15:10] + 1;
            if((r_JOY1DAT[9:8] == 2'b00) & ~M1V) 
                r_JOY1DAT[15:10] <= r_JOY1DAT[15:10] - 1;

            r_JOY1DAT[1] <= ~M1H;
            if((r_JOY1DAT[1:0] == 2'b11) & M1H) 
                r_JOY1DAT[7:2] <= r_JOY1DAT[7:2] + 1;
            if((r_JOY1DAT[1:0] == 2'b00) & ~M1H) 
                r_JOY1DAT[7:2] <= r_JOY1DAT[7:2] - 1;
                 
        end else begin // D0
            r_JOY0DAT[8] <= M0V ^ r_JOY0DAT[9];
            r_JOY0DAT[0] <= M0H ^ r_JOY0DAT[1];
            r_JOY1DAT[8] <= M1V ^ r_JOY1DAT[9];
            r_JOY1DAT[0] <= M1H ^ r_JOY1DAT[1];

        end

        // This case statement emulates the PH0 and PH1 edges within
        // Denise; since async logic is bad in FPGA we'll just use a
        // very trivial state machine
        case({ nCAS, nCDAC })
        2'b11:  begin
                l_RGA <= RGA;
                l_DB <= DB;
                r_BPLxSHIFT <= 0; // 1 for ECS superhires
                r_SPRxSHIFT <= 0; // 1 for ECS superhires             
                end
               
        2'b10:  begin
                case(l_RGA)
                // Collision Storage Register
                8'b0_0000_111 : { r_DB_out, r_CLXDAT, r_DB_out_en } <= { r_CLXDAT, 16'h0000, 1 };
                // Collision Control Register
                8'b0_1001_100 : r_CLXCON <= l_DB;
                // Bit Plane Data Registers (6)
                8'b1_0001_xxx : r_BPLxDAT[l_RGA[2:0]] <= l_DB;
                // Bit Plane Priority & Control Registers
                8'b1_0000_0xx : r_BPLCON[l_RGA[1:0]] <= l_DB;
                // Sprite Data Registers (16)
                8'b1_01xx_x10 : r_SPRxDATA[l_RGA[4:2]] <= l_DB;
                8'b1_01xx_x11 : r_SPRxDATB[l_RGA[4:2]] <= l_DB;
                // Horizontal Sync Counter
                8'b0_0011_110 : r_HCOUNT <= 0;
                // Sprite Horizontal Position Counters
                8'b1_01xx_x00 : r_SPRxPOS[l_RGA[4:2]] <= l_DB;
                8'b1_01xx_x01 : r_SPRxCTL[l_RGA[4:2]] <= l_DB;
                // 32 Color Registers
                8'b1_10xx_xxx : r_COLOR[l_RGA[4:0]] <= l_DB;
                // Joy/Mouse Registers
                8'b0_0000_101 : { r_DB_out, r_DB_out_en } <= { r_JOY0DAT, 1 };
                8'b0_0000_110 : { r_DB_out, r_DB_out_en } <= { r_JOY1DAT, 1 };
                8'b0_0011_011 : { r_JOY0DAT, r_JOY1DAT } = { l_DB, l_DB };
                endcase
               
                r_BPLxSHIFT <= r_BPLCON[0][15]; // Hires
                r_SPRxSHIFT <= 0; // ECS hires sprites         
                end // block
               
        2'b01:  begin
                // Bit Plane Control Register
                if(l_RGA == 8'b1_001_001) begin
                    for(i=0; i<6; i=i+1) begin
                        r_BPLxDAT_latch[i] <= r_BPLxDAT[i];
                    end
                end
                // Sprite Position Compare Logic
                for(i=0; i<8; i=i+1) begin
                    if({r_SPRxPOS[i][7:0], r_SPRxCTL[i][0]} == r_HCOUNT) begin
                        r_SPRxDATA_latch[i] = r_SPRxDATA[i];
                        r_SPRxDATB_latch[i] = r_SPRxDATB[i];
                    end
                end // for
                r_BPLxSHIFT <= 0; // ECS superhires
                r_SPRxSHIFT <= 0; // ECS superhires             
                end
               
        2'b00:  begin
                r_CLXDAT <= r_CLXDAT | w_CLXDAT;
                r_HCOUNT <= r_HCOUNT + 1;
                r_BPLxSHIFT <= 1;
                r_SPRxSHIFT <= 1;     
                r_DB_out_en <= 0;          
                end // block
        endcase
       
        if(r_BPLxSHIFT) begin
            // Serialize bit plane registers
            for(i=0; i<6; i=i+1) begin
                // Parallel-In, Serial-Out Shift Register
                r_BPLxDAT_latch[i] <= { r_BPLxDAT_latch[i][14:0], 1'b0 };
                // Serial-In, Parallel-Out Shift Register
                r_BPLxDAT_pixel[i] <= { r_BPLxDAT_pixel[i][14:0], r_BPLxDAT_latch[15] };
                // Serial bit plane data with horizontal scroll
                r_BPL_SER[i] <= r_BPLxDAT_pixel[i][w_HSHIFT];
            end // for       
        end
       
        // Serialize sprite registers
        for(i=0; i<8; i=i+1) begin
            if(r_SPRxSHIFT[i]) begin
                // Parallel-In, Serial-Out Shift Registers
                r_SPRxDATA_latch[i] <= { r_SPRxDATA_latch[i][14:0], 1'b0 };
                r_SPRxDATB_latch[i] <= { r_SPRxDATB_latch[i][14:0], 1'b0 };
                // Serial bit plane data
                r_SPR_SERA[i] <= r_SPRxDATA_pixel[15];
                r_SPR_SERA[i] <= r_SPRxDATB_pixel[15];
            end
        end // for
    end
endmodule