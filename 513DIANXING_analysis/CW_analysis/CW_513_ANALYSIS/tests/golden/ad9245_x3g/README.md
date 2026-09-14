# AD9245 X3G 重构前黄金摘要

2026-09-09起，AD2208/AD9245默认INL/DNL码端余量为0。此处INL/DNL摘要保留为历史结果，不是新默认参数的数值基线；未重新计算原始数据，不应直接以它判定新默认参数回归通过。其他指标不受这项参数修改影响。

这些小型 CSV 由标签 `ad9245-pre-refactor-20260808` 的代码和
`513_GS_AD_DATA/AD9245` 历史 X3G 原始数据重新生成，仅用于对比数值和字段，
不包含原始采样数据。功率刻度基线保留为历史 dB/dBm 方法证据，不再由
`run_golden_regression` 与当前 `CodePp → Vpp` 正式刻度比较；当前刻度由
`ad9245WorkflowTest` 的方向和字段测试覆盖。

| 文件 | 原文件 SHA-256 |
|---|---|
| ADC_SFDR_summary.csv | BEE20F18CCD23E453A68B440C6B14C730C6E353F14796DDCB7540095A99F0199 |
| ADC_bandwidth_summary.csv | 9042B63E6D4860910E9550A8049FE269F105A7E185F0FB6943F32E3E2AAB38A9 |
| ADC_power_scale_summary.csv | EFD2AB87D4AB14E8A3B2F08C741206C5EB4B17B4360E2AC4C3C7B691687F9166（历史） |
| ADC_isolation_summary.csv | 2237B1D9957CF8601937184925500D49251E6EA652DA546E43A48A1CD308BBBB |
| ADC_inl_dnl_summary.csv | FFAC4D19B3171B113EFFB89FDDAEA518DB2E421CB1548225AA1B6B5C3095C89A |

比较规则：字段名、顺序、整数、布尔和字符串完全一致；dB 与拟合指标绝对误差不超过 `1e-9`；频率和码值相对误差不超过 `1e-12`。图片只检查文件、坐标单位和曲线数量。

原始数据未上传到 Git。若本机仍有对应的历史数据，可运行：

```matlab
run_golden_regression('.../513_GS_AD_DATA/AD9245')
```
