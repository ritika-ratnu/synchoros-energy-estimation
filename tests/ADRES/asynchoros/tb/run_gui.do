vlog -work work ../rtl/rtl/pkg.sv
vlog -work work ../rtl/rtl/config_mem.sv
vlog -work work ../rtl/rtl/reg_file.sv 
vlog -work work ../rtl/rtl/output_register.sv
vlog -work work ../rtl/rtl/simple_alu.sv
vlog -work work ../rtl/rtl/tile.sv
vlog -work work ../rtl/rtl/global_controller.sv
vlog -work work ../rtl/rtl/ADRES.sv
vlog -work work ../rtl/tb/tb_ADRES.sv
vsim work.tb -vopt -voptargs=+acc -t ns;
