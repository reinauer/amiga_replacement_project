// Copyright 2011, 2012 Frederic Requin
// Copyright 2024, 2025 Renee Cousins, The Buffee project, Inc
//  
// See README.md for details

////////////////////////
// Color lookup table //
////////////////////////

module ColourTable(
  input         clk,

  input         cpu_wr,
  input   [4:0] cpu_idx,
  input  [11:0] cpu_rgb,

  input         clut_rd,
  input   [4:0] clut_idx,
  output [11:0] clut_rgb
);

    // Infered block RAM
    reg  [11:0] r_mem_clut [0:31];

    // Write port
    always@(posedge clk) begin
        if (cpu_wr) begin
            r_mem_clut[cpu_idx] <= cpu_rgb;
        end
    end

    reg  [11:0] r_q_p0;
    reg  [11:0] r_q_p1;

    // Read port
    always@(posedge clk) begin
        if (clut_rd) r_q_p0 <= r_mem_clut[clut_idx];
        r_q_p1 <= r_q_p0;
    end

    assign clut_rgb = r_q_p1;

endmodule