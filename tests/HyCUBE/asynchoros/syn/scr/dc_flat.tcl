################################################################################
# Design Compiler logic synthesis script
################################################################################
#
# This script is meant to be executed with the following directory structure
#
# project_top_folder
# |
# |- db: store output data like mapped designs or physical files like GDSII
# |
# |- phy: physical synthesis material (scripts, pins, etc)
# |
# |- rtl: contains rtl code for the design, it should also contain a
# |       hierarchy.txt file with the all the files that compose the design
# |
# |- syn: logic synthesis material (this script, SDC constraints, etc)
# |
# |- sim: simulation stuff like waveforms, reports, coverage etc.
# |
# |- tb: testbenches for the rtl code
# |
# |- exe: the directory where it should be executed. This keeps all the temp files
#         created by DC in that directory
#
#
# The standard way of executing the is from the project_top_folder
# with the following command
#
# $ genus -files ../syn/genus_synthesis.tcl
#
# Additionally it should be possible to do
#
# $ make syn
#
# If the standard Makefile is present in the project directory
# Please check if you have the right constraints in ./syn/constraints.sdc
# Additionaly, please make sure that you have replaced SRAM_model with SRAM Macro
################################################################################
puts [pwd]
## Configuration variables
set CPU_NUM 12
set EFFORT high

set LIB_NAME "tcbn28hpcbwp30p140ssg0p81v125c.db ts1n28hpcsvtb128x128m4swbasod_170b_ssg0p72v0p81v125c.db"
#set LIB_SEARCH_PATH "/mnt/storage3/stdc_libs/28LP/stdclib/9-track/30p140/nvt/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28lpbwp30p140_142b"
set LIB_SEARCH_PATH "/opt/stdc_libs/28HPC/stclib/9-track/30p140/nvt/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcbwp30p140_100a \
                     /opt/stdc_libs/28HPC/ts1n28hpcsvtb128x128m4swbasod_170b/NLDM \
                     /opt/synopsys/syn/T-2022.03-SP2/libraries/syn"
set synlib "/opt/synopsys/syn/T-2022.03-SP2/libraries/syn/dw_foundation.sldb"
set synthetic_library "${synthetic_library} $synlib /opt/synopsys/syn/T-2022.03-SP2/libraries/syn/standard.sldb"
set OP_CONDS ssg0p81v125c

# Directories for output material
set REPORT_DIR  ../syn/rpt;      # synthesis reports: timing, area, etc.
set OUT_DIR ../syn/db;           # output files: netlist, sdf sdc etc.
set SOURCE_DIR ../rtl;           # rtl code that should be synthesised
set SYN_DIR ../syn;              # synthesis directory, synthesis scripts constraints etc.

# Design specific variables
if {[info exists ::env(TOP_NAME)]} {
    set TOP_NAME ${::env(TOP_NAME)}
} else {
    set TOP_NAME silagonn
}

# prefix for report and output names
if {[info exists ::env(PREFIX)]} {
    set PREFIX $::env(PREFIX)
} else {
    set PREFIX ""
}

# sufix for report and output names
if {[info exists ::env(SUFFIX)]} {
    set SUFFIX $::env(SUFFIX)
} else {
    set SUFFIX ""
}

if {[info exists ::env(SAVE_STEPS)]} {
    set SAVE_STEPS $::env(SAVE_STEPS)
} else {
    set SAVE_STEPS false
}

if {[info exists ::env(START_TIMESTAMP)]} {
    set start_timestamp $::env(START_TIMESTAMP)
} else {
    set start_timestamp [clock format [clock seconds] -format %y%m%d_%H%M]
}

#library setup
set search_path ${LIB_SEARCH_PATH}
set target_library ${LIB_NAME}
set link_library "* ${LIB_NAME} ${synthetic_library}"

# syn setup
set compile_timing_high_effort true
set_host_options -max_cores ${CPU_NUM}

# Read packages
set hierarchy_files [split [read [open ${SOURCE_DIR}/silagonn_hierarchy.txt r]] "\n"]

# source sdc file
source ${SYN_DIR}/constraints.sdc
# assume .vhd extensions are VHDL and others are Verilog netlist
# skip the last element since tcl reads {} for the last line
foreach filename [lrange ${hierarchy_files} 0 end-1] {
    # puts "${filename}"
    # ignore file if line starts with #
    if {![string equal [string index $filename 0] "#"]} {
        if {[string equal [file extension $filename] ".vhd"]} {
            analyze -format vhdl -lib WORK ${SOURCE_DIR}/${filename}
        } elseif {[string equal [file extension $filename] ".v"]} {
            analyze -format verilog -lib WORK ${SOURCE_DIR}/${filename}
        }
    }
}

current_design ${TOP_NAME}
elaborate ${TOP_NAME}
link 
uniquify
compile

report_timing > "${REPORT_DIR}/${PREFIX}${TOP_NAME}_${start_timestamp}_timing${SUFFIX}.txt"
report_power  > "${REPORT_DIR}/${PREFIX}${TOP_NAME}_${start_timestamp}_power${SUFFIX}.txt"
report_area   > "${REPORT_DIR}/${PREFIX}${TOP_NAME}_${start_timestamp}_area${SUFFIX}.txt"

write_file -format verilog -hier -output "${OUT_DIR}/${PREFIX}${TOP_NAME}_${start_timestamp}${SUFFIX}.v"
write_file -format ddc     -hier -output "${OUT_DIR}/${PREFIX}${TOP_NAME}_${start_timestamp}${SUFFIX}.ddc"
write_sdc "${OUT_DIR}/${PREFIX}${TOP_NAME}_${start_timestamp}${SUFFIX}.sdc"
write_sdf "${OUT_DIR}/${PREFIX}${TOP_NAME}_${start_timestamp}${SUFFIX}.sdf"
exit
