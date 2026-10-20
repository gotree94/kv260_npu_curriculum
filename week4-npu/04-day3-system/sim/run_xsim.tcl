set origin_dir [file dirname [file normalize [info script]]]
set sys_dir    [file normalize [file join $origin_dir .. rtl]]
set arr_dir    [file normalize [file join $origin_dir .. .. 03-day2-systolic rtl]]

cd $origin_dir

if {[file exists work]} {
    file delete -force work
}

xvlog $arr_dir/pe.v
xvlog $arr_dir/systolic_array.v
xvlog $sys_dir/npu_ctrl.v
xvlog tb_npu_ctrl.v

xelab tb_npu_ctrl -s tb_npu_ctrl_snap
xsim tb_npu_ctrl_snap -R
