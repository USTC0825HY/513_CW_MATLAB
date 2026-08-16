# CW_513_ANALYSIS workflow迁移映射

| 旧算法文件 | 当前兼容入口 | 新公共实现 |
|---|---|---|
| `s08_calibrate_dac_multi_sine.m` | `01_workflows/03_calibration/s08_calibrate_dac_multi_sine.m` | `CW_513_ANALYSIS/_shared/+converter/+dac/runScale.m` |
| `s11_analyze_dac_output_noise_metrics.m` | `01_workflows/04_noise_and_chain/s11_analyze_dac_output_noise_metrics.m` | `CW_513_ANALYSIS/_shared/+converter/+dac/runNoise.m` |
| `s17_batch_da766_dc_noise.m` | `01_workflows/04_noise_and_chain/s17_batch_da766_dc_noise.m` | `CW_513_ANALYSIS/766_hy/dac_noise_analysis.m` |
| `s28_analyze_channel_isolation.m` | `01_workflows/05_dynamic_and_linearity/s28_analyze_channel_isolation.m` | `CW_513_ANALYSIS/_shared/+converter/+dac/runIsolation.m` |

归档文件只用于历史复核，不应被新的器件入口调用。
