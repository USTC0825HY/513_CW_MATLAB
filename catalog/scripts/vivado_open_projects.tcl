set projects [list \
    {F:/01_Laser/code/fpga/projects/cwjg/cwjg_v3_2_20/CWJG_VER3.xpr} \
    {F:/01_Laser/code/fpga/projects/cwjg/cwjg_v3_3_11/CWJG_VER3.3_11/CWJG_VER3.xpr} \
    {F:/01_Laser/code/fpga/projects/gs_delay_20260730/Vivado_Project/jianding_szsd_ver729/jianding_szsd_ver729.xpr} \
    {F:/01_Laser/code/fpga/projects/cw_test_202608/AD766_RF_test/vivado_project/AD766_RF_test.xpr} \
    {F:/01_Laser/code/fpga/projects/cw_test_202608/AD766_RF_test/build/AD677_IO_DDS_formal_v6_ila128k/AD677_IO_DDS_formal_v6_ila128k.xpr} \
    {F:/01_Laser/code/fpga/legacy/jianding_szsd_old/jianding_szsd.xpr} \
]

set failures 0
foreach project_file $projects {
    puts "VALIDATING_PROJECT: $project_file"
    if {[catch {open_project -read_only $project_file} message]} {
        puts "VALIDATION_FAILED: $message"
        incr failures
    } else {
        puts "VALIDATION_PASSED: [current_project]"
        close_project
    }
}

puts "PROJECT_COUNT: [llength $projects]"
puts "FAILURE_COUNT: $failures"
if {$failures > 0} {
    exit 1
}
exit 0
