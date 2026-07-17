vlog -work work ../rtl/rtl/SmartPkg.sv
vlog -work work ../rtl/rtl/TopPkg.sv
vlog -work work ../rtl/rtl/encoder_onehot.sv 
vlog -work work ../rtl/rtl/xbar_bypass.sv
vlog -work work ../rtl/rtl/router.sv
vlog -work work ../rtl/rtl/simple_alu.sv
vlog -work work ../rtl/rtl/tile.sv
vlog -work work ../rtl/rtl/globals_network.sv
vcom -2008 -work work ../rtl/macros/TSDN40LPA512X32M4F.vhd
vcom -2008 -work work ../rtl/macros/TS6N40LPA24X64M2F.vhd
vlog -work work ../rtl/rtl/hycube_unrolled.sv
vlog -work work ../rtl/tb/tb_hycube.sv
vsim work.tb -vopt -voptargs=+acc -t ns;
do wave.do
run 1600ns;
