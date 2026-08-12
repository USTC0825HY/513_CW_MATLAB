set projects [list \
    {F:/01_Laser/code/fpga/projects/cwjg/cwjg_v3_2_20/CWJG_VER3.xpr} \
    {F:/01_Laser/code/fpga/projects/cwjg/cwjg_v3_3_11/CWJG_VER3.3_11/CWJG_VER3.xpr} \
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
exit $failures
