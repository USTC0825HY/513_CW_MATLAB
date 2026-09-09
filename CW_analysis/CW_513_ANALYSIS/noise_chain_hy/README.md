# CW 513 ADC 输入等效噪声入口

正式入口为 `adc_input_equiv_noise_analysis.m`。它位于
`CW_513_ANALYSIS` 库，调用 `_shared/+converter/+io/loadPicoMat.m`、
`_shared/+converter/+report` 和 `_shared/+converter/+runtime/sha256File.m`，不依赖
`laser_analysis/01_workflows` 的运行时路径。

算法沿用历史 `s09_analyze_ad_input_equiv_noise_new_flow.m` 中已经审核过的
ADC-FPGA-DAC 输入等效换算关系，现使用本库入口、刻度配置或显式指定的工作簿，以及
结果包格式。历史脚本仅作为兼容/方法参考，不是本入口的执行依赖。

`S_in(f)=S_PICO(f)*(k_ADC/(abs(G_FPGA)*k_DAC))^2`；默认不扣除 PICO/DAC
本底。原始 MAT 文件完整性不足时，入口只写入审计行并标记“暂不能判定”。
