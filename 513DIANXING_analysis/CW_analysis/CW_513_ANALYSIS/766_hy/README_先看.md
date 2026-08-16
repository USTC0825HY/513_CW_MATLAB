# DA766 CW_513_ANALYSIS入口

当前库内入口：`dac_scale_analysis`、`dac_noise_analysis`、`dac_isolation_analysis`；批处理为`run_da766_batch`，结果审计为`audit_da766_results`。

噪声入口按记录长度重新计算Welch分辨率，不继承历史1 Hz配置。当前需求版本存在冲突，正式判定默认关闭，结果中的数值和覆盖质量仍完整保存。

本阶段不处理相噪、输出电压、线性度以及更新率/分辨率。
