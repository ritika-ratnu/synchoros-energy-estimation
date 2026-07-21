puts [pwd]
set CPU_NUM 12
set EFFORT high

source ../syn/scr/library.tcl

# Directories for output material
set TOP_NAME ADRES
set REPORT_DIR  ../syn/rpt;      # synthesis reports: timing, area, etc.
set OUT_DIR ../syn/db;           # output files: netlist, sdf sdc etc.
set SOURCE_DIR ../rtl/rtl;           # rtl code that should be synthesised
set SYN_DIR ../syn;              # synthesis directory, synthesis scripts constraints etc.

#library setup
set search_path ${LIB_SEARCH_PATH}
set target_library ${LIB_NAME}
set link_library "* ${LIB_NAME} ${synthetic_library}"

# syn setup
set compile_timing_high_effort true
set_host_options -max_cores ${CPU_NUM}

set hierarchy_files [split [read [open ${SOURCE_DIR}/ADRES_hierarchy.txt r]] "\n"]

foreach filename [lrange ${hierarchy_files} 0 end-1] {
    if {![string equal [string index $filename 0] "#"]} {
        if {[string equal [file extension $filename] ".vhd"]} {
            analyze -format vhdl -lib WORK ${SOURCE_DIR}/${filename}
        } elseif {[string equal [file extension $filename] ".sv"]} {
            analyze -format sverilog -lib WORK ${SOURCE_DIR}/${filename}
        }
    }
}

elaborate ${TOP_NAME}
current_design ${TOP_NAME}
source ${SYN_DIR}/constraints.sdc
link 
#if {[sizeof_collection $mem_cells] > 0} {
#  set_dont_touch $mem_cells
#  # Mark memory outputs ideal to trim cones during early iterations
#  set mem_out_pins [all_outputs -of $mem_cells]
#  if {[sizeof_collection $mem_out_pins] > 0} {
#    set_ideal_network $mem_out_pins
#  }
#}
#uniquify
compile
report_timing > "${REPORT_DIR}/${TOP_NAME}_timing.txt"
report_power  > "${REPORT_DIR}/${TOP_NAME}_power.txt"
report_area   > "${REPORT_DIR}/${TOP_NAME}_area.txt"

write_file -format verilog -hier -output "${OUT_DIR}/${TOP_NAME}.v"
write_file -format ddc     -hier -output "${OUT_DIR}/${TOP_NAME}.ddc"
write_sdc "${OUT_DIR}/${TOP_NAME}.sdc"
write_sdf "${OUT_DIR}/${TOP_NAME}.sdf"
exit
