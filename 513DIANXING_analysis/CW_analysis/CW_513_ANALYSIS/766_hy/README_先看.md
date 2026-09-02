# DA766 CW_513_ANALYSIS入口

当前库内入口：`dac_scale_analysis`、`dac_noise_analysis`、`dac_isolation_analysis`；批处理为`run_da766_batch`，结果审计为`audit_da766_results`。

DA766 `06_scale` 数据的刻度文件名使用 `CODE1000`、`CODE1000-0002` 和
`CODE7FFF` 等无符号十六进制码值。本批次使用新增入口
`dac_scale_hex_analysis` 和 `run_da766_scale_hex_batch`：先按 16 bit 补码转换为
有符号十进制，再按 `CodePp = 2*abs(signed_code)` 拟合
`Vpp = slope*CodePp + intercept`。波形证据显示本批实际音调为 1525 Hz，不能
直接沿用旧模板的 1 kHz；每个通道的实际 `1/Tinterval` 和拟合质量仍写入结果表。
本次全量重算将 `0x7FFF` 纳入拟合，最大 `CodePp` 门槛设置为 `2^16`；每个接口
单独输出一张 PNG/FIG 刻度图，`k`、`b` 同时以科学计数法写入汇总表。

`X7_CODE*_CH2.mat` 为历史 CH2 文件，本批次不混入标准 X7 通道，排除原因记录在
`DA766_scale_input_selection.csv`。正式判定仍由 `formalEnabled=false` 约束为“暂不能判定”。

噪声入口按记录长度重新计算Welch分辨率，不继承历史1 Hz配置。当前需求版本存在冲突，正式判定默认关闭，结果中的数值和覆盖质量仍完整保存。

本阶段不处理相噪、输出电压、线性度以及更新率/分辨率。
