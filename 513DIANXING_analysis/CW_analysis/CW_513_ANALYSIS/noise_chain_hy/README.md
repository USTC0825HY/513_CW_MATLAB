# CW 513 ADC 输入等效噪声公共内核

日常运行2208、9245或677目录中的单项噪声入口，由入口负责文件、接口和板型选择。内核也接受显式配置；使用内置报告刻度时必须给出 `boardType='jianding'` 或 `'jiaqiang'`，并明确 `entries`。默认 `calibrationState='current'`。自定义ADC刻度与DAC刻度须成对指定。规则和55条报告记录见 [CALIBRATION.md](../CALIBRATION.md)。

运行读取随代码发布的刻度CSV；报告文件名与SHA-256用于溯源，不在运行时打开Word或搜索历史刻度结果目录。`evidence/selected_adc_calibration.csv`、`selected_dac_calibration.csv`和`result.mat`记录实际使用值。

正式入口为 `adc_input_equiv_noise_analysis.m`。它位于
`CW_513_ANALYSIS` 库，调用 `_shared/+converter/+io/loadPicoMat.m`、
`_shared/+converter/+report` 和 `_shared/+converter/+runtime/sha256File.m`，不依赖
`laser_analysis/01_workflows` 的运行时路径。

算法沿用历史 `s09_analyze_ad_input_equiv_noise_new_flow.m` 中已经审核过的
ADC-FPGA-DAC 输入等效换算关系，现使用本库入口、刻度配置或显式指定的工作簿，以及
结果包格式。历史脚本仅作为兼容/方法参考，不是本入口的执行依赖。

`S_in(f)=S_PICO(f)*(k_ADC/(abs(G_FPGA)*k_DAC))^2`；默认不扣除 PICO/DAC
本底。原始 MAT 文件完整性不足时，入口只写入审计行并标记“暂不能判定”。
