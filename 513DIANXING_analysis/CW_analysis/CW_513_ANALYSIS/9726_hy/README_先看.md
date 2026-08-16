# DA9726 CW_513_ANALYSIS入口

当前库内入口：`dac_scale_analysis`、`dac_noise_analysis`、`dac_isolation_analysis`；批处理为`run_da9726_batch`，结果审计为`audit_da9726_results`。

噪声入口使用0.2 Hz目标Welch分辨率和最少4段覆盖门槛；采集负载或参考面缺失时，数值仍可追溯，但正式结论为“暂不能判定”。

本阶段不处理相噪、输出电压和线性度。刻度文件必须包含文件名码值（例如 `code_30000`）和Pico MAT电压通道。
