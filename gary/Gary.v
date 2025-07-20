////////////////////////////////////////////////////////////////////////////////// 
// 
// Company:        The Buffee Project Inc.
// Engineers:      c. 2022 Renee Cousins
//                 c. 2015 Matthias 'Matze' Heinrichs
// 
// Create Date:    20:24:47 10/29/2015
// Design Name:    Gary
// Project Name:   Amiga Replacement Project
// Target Devices: XC9572XL
// Tool versions:  Xilinx ISE 13
// Description:    Implements the original logic of the Commodore Amiga
//                 CSG 5719 "Gary" chip. The original specification as far
//                 as it is known should be included in this archive. 
// Dependencies:   None
// 
// Revision:       0.01 - File Created
//                 0.20 - First working version (>90% boots pass)
//                 0.21 - Added waitstates for RTC and BGACK
//                 0.30 - Complete rework. Matches original Gary behaviour in 99.999%. Influence of BGACK is unclear
// 
////////////////////////////////////////////////////////////////////////////////// 
module Gary(           //                     ACTV HANDLED
                       // PIN NAME    TYPE    PLTY BY      DESCRIPTION
                       // --- ------- ------- ---- ------- --------------------------
                       //  1  VSS     PWR          n/a     Common ground supply
    output nVPA,       //  2  NVPA    OUT     LO   PALEN   Valid peripheral address 
    output nCDR,       //  3  NCDR    OUT     LO   PALCAS  Enable video bus read buffers
    output nCDW,       //  4  NCDW    OUT     LO   PALCAS  Enable video bus output buffers
    input nKRES,       //  5  NKRES   IN      LO   n/a     Power-up/Keybd Reset 
                       //  6  VDD     PWR          n/a     Common 5v supply
    input nMTR,        //  7  NMTR    IN      LO   n/a     Disk motor enable 
    input nDKWD,       //  8  NDKWD   IN      LO   n/a     Disk write data
    input nDKWE,       //  9  NDKWE   IN      HI   n/a     Disk write enable
    input nLDS,        // 10  NLDS    IN      LO   n/a     68000 lower byte data strobe
    input nUDS,        // 11  NUDS    IN      LO   n/a     68000 upper byte data strobe
    input RW,          // 12  PPRnW   IN      LO   n/a     68000 write enable
    input nAS,         // 13  NAS     IN      LO   n/a     68000 Adress strobe
    input nBGACK,      // 14  NBGACK  IN      LO   n/a     Bus grant acknowledge; add 1WS
    input nDBR,        // 15  NDBR    IN      LO   n/a     DMA bus request 
    input nSEL0,       // 16  NSEL0   IN      LO   n/a     (??)
                       // 17  VDD     PWR          n/a     Common 5v supply
    output nRGAE,      // 18  NRGAE   OUT     LO   PALEN   Amiga chip register address decode
    output nBLS,       // 19  NBLS    OUT     LO   PALEN   Blitter slowdown
    output nRAME,      // 20  NRAME   OUT     LO   PALEN   Video RAM address decode
    output nROME,      // 21  NROME   OUT     LO   PALEN   On-board ROM address decode
    output nRTCR,      // 22  NRTCR   OUT     LO   PALCAS  Real time clock read enable; add 3WS
    output nRTCW,      // 23  NRTCW   OUT     LO   PALCAS  Real time clock write enable; add 3WS
                       // 24  VSS     PWR          n/a     Common ground supply
    output reg nLATCH, // 25  C4      OUT     LO   CLOCKS  Enable video bus read latch (LS373 EN)
    input nCDAC,       // 26  NCDAC   IN      CLK  n/a     7.14Mhz clk (high while C3 changes)
    input C3,          // 27  C3      IN      CLK  n/a     3.57Mhz clk (90 deg lag of C1)
    input C1,          // 28  C1      IN      CLK  n/a     3.57Mhz clk 
    input nOVR,        // 29  NOVR    IN      LO   n/a     Override (internal decoding and DTACK)
    input OVL,         // 30  OVL     IN      HI   n/a     Overlay (ROM to address 0)
    input XRDY,        // 31  XRDY    IN      HI   n/a     External ready
    input nEXP,        // 32  NEXP    IN      LO   n/a     Expansion Ram (present)
    input [23:17] A,   // 33  A17     IN      HI   n/a     68000 CPU Address
                       // 34  A18     IN      HI   n/a     68000 CPU Address
                       // 35  A19     IN      HI   n/a     68000 CPU Address
                       // 36  A20     IN      HI   n/a     68000 CPU Address
                       // 37  A21     IN      HI   n/a     68000 CPU Address
                       // 38  A22     IN      HI   n/a     68000 CPU Address
                       // 39  A23     IN      HI   n/a     68000 CPU Address
                       // 40  N/C                  n/a     No connect
    inout nRESET,      // 41  NRESET  OUT OD  LO   FILTER  68000 reset; OD feed back from bus
    output nHALT,      // 42  NHALT   OUT OD  LO   FILTER  68000 halt
    output nDTACK,     // 43  NDTACK  OUT TS  LO   PALEN   Data transfer acknowledge
    output DKWEB,      // 44  DKWEB   OUT     HI           Disk write enable buffered
    output DKWDB,      // 45  DKWDB   OUT     HI           Disk write data buffered
    output MTR0D,      // 46  MTR0D   OUT     HI           Latched disk 0 motor on (?)
    output MTRXD       // 47  MTRXD   OUT     HI           Buffered NMTR 
                       // 48  VDD     PWR          n/a     Common 5v supply
);

    // internal registers
    reg nDTACK_S, nCDR_S, nCDW_S, MTR0_S,nBUS_ACCESS;
	reg [3:0]C1_D;
	reg [3:0]C3_D;
	reg [3:0]nAS_QUAL;
	reg GO;
	reg nRAME_S, nRGAE_S;
	localparam [3:0] PHASE=1; 
    // RESET is open-drain, input/output (IOBUFE)
    assign nRESET = nKRES ? 1'bz : 1'b0;
    // HALT is open-drain, output only
    assign nHALT = nRESET ? 1'bz : 1'b0;
    // Global ENABLE signal
    wire ENABLE = nRESET & nOVR & ~nAS ;
    // DTACK is tri-state, output only
    assign nDTACK = ENABLE ? nDTACK_S : 1'bz;

    // generate processor clock
    wire C7M = C3 ~^ C1;                    // 7MHz (c1 xnor c2)
    wire C14M = C7M ~^ nCDAC;               // 14MHz (7MHz xnor CDAC)
    wire DS = ~nUDS | ~nLDS;                // Either data select
    
    // ADDRESS DECODE
    wire CHIPRAM    = (~OVL & A[23:21]==3'b000)   //    000000-1FFFFF
					| (~nEXP &                    // expansion present and
                     (A[23:19]==5'b11000));       //    C00000-C7FFFF ranger
    
    wire ROM        = ((OVL & A[23:21]==3'b000)   // ROM overlay during start
                    | (A[23:19]==5'b1111_1)       // or F80000-FFFFFF
                    | (A[23:19]==5'b1110_0));     // or E00000-E7FFFF
                    
    wire CIA        = A[23:20]==4'b1011;          //    B00000-BFFFFF CIA
    
    wire CLOCK      = A[23:17]==7'b1101_110;      //    DC0000-DDFFFF clock
    
    wire CHIPSET    = nEXP & (A[23:19]==5'b11001) // expansion absent and C00000-C7FFFF
                    | (A[23:17]==7'b1101_111);    // or DE0000-DFFFFF chipset                    				
        
    // assign simple signals
    assign DKWDB = ~nDKWD;
    assign DKWEB = nDKWE & nRESET;
    assign MTRXD = ~nMTR & nRESET;
    assign MTR0D = MTR0_S;
    
    wire AGNUS = CHIPRAM | CHIPSET;
    
    // select floppy motor
    always @(negedge nSEL0, negedge nRESET) 
        MTR0_S <= (nRESET==0) ? 0 : ~nMTR;
    
	always @(negedge nCDAC)
	begin
		//this replaces the nasty latch!
		nLATCH	<=	C3;
	end
	
    // decode address and generate the internal signals
    always @(posedge C14M) begin
		C1_D <= {C1_D[2:0],C1};
		C3_D <= {C3_D[2:0],C3};		
        if(nAS | ~nRESET) begin
            nDTACK_S    <= 1;
            nCDR_S      <= 1;
            nCDW_S      <= 1;
			nBUS_ACCESS <= 1;
			nAS_QUAL <= 4'b1111;			
			GO <= 1;
			nRAME_S <= 1;
			nRGAE_S <= 1;
        end 
		else begin
		
			if(~C3_D[PHASE] & ~C1_D[PHASE] & nAS_QUAL == 4'b1111) 
				nAS_QUAL <= 4'b0000;
			else 
				if (nAS_QUAL != 4'b1111);
					nAS_QUAL <=  nAS_QUAL + 1;
		
			if(nAS_QUAL == 4'b0010 & CHIPRAM)
				nRAME_S <= 0;

			if(nAS_QUAL == 4'b0010 & CHIPSET)
				nRGAE_S <= 0;

		
			if( (nDBR & nDTACK_S & ~C1_D[PHASE] & C3_D[PHASE] & AGNUS)
				|(~nBUS_ACCESS & ~C1_D[PHASE] & ~C3_D[PHASE])
				) 
				nBUS_ACCESS <= 0;
			else
				nBUS_ACCESS <= 1;
		            
            // assert DTACK when ready
			if(   (~nBUS_ACCESS & ~C3_D[PHASE])
				| (XRDY & ((~CIA & ~AGNUS)|~nDTACK_S)) // XRDY high and all others except CIA or hold
				)
				nDTACK_S <= 0;
			else
				nDTACK_S <= 1;
            


            // read from RAM / register  
            if(~nBUS_ACCESS // Agnus and access granted
				& RW //read
				&C1_D[PHASE] 
				)
                nCDR_S  <= 0;
				
            // write to RAM / register
			if(	(~nBUS_ACCESS //Agnus and access granted
				& ~RW) //write
				| (~nCDW_S & C1_D[PHASE])
				)
                nCDW_S  <= 0;
			else 
				nCDW_S  <= 1;
        end
    end
        
    // output signal generation
    assign nVPA =   ENABLE ? ~CIA : 1'bz;
    assign nROME =  ENABLE ? ~(ROM & RW) : 1; // only on read!
    assign nRTCR =  ENABLE ? ~(CLOCK &  RW & DS) : 1;
    assign nRTCW =  ENABLE ? ~(CLOCK & ~RW & DS) : 1;
    assign nRAME =  ~CHIPRAM;
    assign nRGAE =  ~CHIPSET;
    assign nCDR  =  ENABLE ? nCDR_S : 1;
    assign nCDW  =  ENABLE ? nCDW_S : 1;
	// slow down blitter
    assign nBLS  =  nBUS_ACCESS;

endmodule