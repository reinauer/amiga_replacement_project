// Color lookup table

module color_table(
    input         clk,

    input         cpu_wr,
    input   [4:0] cpu_idx,
    input  [11:0] cpu_rgb,

    input         clut_rd,
    input   [4:0] clut_idx,
    output [11:0] clut_rgb
);
    reg [15:0] mem [31:0];

    always @(posedge clk)
    begin
        if (cpu_wr)
            mem[cpu_idx] <= { 4'b0, cpu_rgb };

        if (clut_rd)
            clut_rgb <= mem[clut_idx][11:0];
    end

endmodule