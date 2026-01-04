rm denise.bin denise.txt denise.json || true
yosys -q -p 'synth_ice40 -top top -json denise.json' src/denise.v src/top.v
nextpnr-ice40 --hx8k --json denise.json --freq 57 --pcf constraints/denise.pcf --package cb132 --asc denise.txt
icepack denise.txt denise.bin
iceprog -d i:0x0403:0x06011 denise.bin