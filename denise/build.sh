rm denise.bin denise.txt denise.json || true
yosys -q -p 'synth_ice40 -top top -json denise.json' src/denise.v src/top.v
nextpnr-ice40 --hx8k --json denise.json --pcf constraints/denise.pcf --package cb132 --asc denise.txt
icepack denise.txt denise.bin


quad m0h_quad(
    .clk (clk),
    .cckq(cckq),
    .cck (cck),
    .quad(m0h),
    .data(r_m0h_data)
);

quad m0v_quad(
    .clk (clk),
    .cckq(cckq),
    .cck (cck),
    .quad(m0v),
    .data(r_m0v_data)
);

quad m1h_quad(
    .clk (clk),
    .cckq(cckq),
    .cck (cck),
    .quad(m1h),
    .data(r_m1h_data)
);

quad m1v_quad(
    .clk (clk),
    .cckq(cckq),
    .cck (cck),
    .quad(m1v),
    .data(r_m1v_data)
);