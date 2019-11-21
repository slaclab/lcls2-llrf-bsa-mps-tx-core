# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for submodule tagging
if { [info exists ::env(OVERRIDE_SUBMODULE_LOCKS)] != 1 || $::env(OVERRIDE_SUBMODULE_LOCKS) == 0 } {
   if { [SubmoduleCheck {ruckus} {2.0.1}  ] < 0 } {exit -1}
   if { [SubmoduleCheck {surf}   {2.0.0}  ] < 0 } {exit -1}
} else {
   puts "\n\n*********************************************************"
   puts "OVERRIDE_SUBMODULE_LOCKS != 0"
   puts "Ignoring the submodule locks in axi-pcie-core/ruckus.tcl"
   puts "*********************************************************\n\n"
} 

# Check for version 2016.4 of Vivado (or later)
if { [VersionCheck 2016.4] < 0 } {exit -1}

# Load Source Code
loadSource -lib lcls2_llrf_bsa_mps_tx_core -dir "$::DIR_PATH/rtl"
