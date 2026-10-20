set origin_dir [file dirname [file normalize [info script]]]
set rtl_dir    [file normalize [file join $origin_dir .. rtl]]

cd $origin_dir

if {[file exists work]} {
    file delete -force work
}

xvlog $rtl_dir/pe.v
xvlog $rtl_dir/systolic_array.v
xvlog tb_systolic.v

xelab tb_systolic -s tb_systolic_snap
xsim tb_systolic_snap -R
