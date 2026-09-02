# AD677 输入频率与输入功率分析

本目录只提供 AD677 的两个入口：`adc_bandwidth_analysis.m` 和
`adc_power_scale_analysis.m`。二者复用相邻 `_shared/+converter/+adc`
中的唯一算法实现，不包含 SFDR、隔离度或 INL/DNL。

采集证据为 16 位 signed two's-complement 十进制码，ADC 数据位于 CSV
第 4 列，第 5 列为 `adc_data_vld`；ILA 以 100 MHz 记录，转换码在有效脉冲
之间保持。通道由 CSV 头的 `u_ad677_1/2` 映射为 `677_1/677_2`。

输入功率刻度严格拟合 `Vpp = a*CodePp + b`，横轴 CodePp、纵轴 Vpp。
manifest 表明信号源为 SDG6032X-E 且输出模式为 High-Z；这里的 Vpp 是
信号源显示设置值。板连接器、实际终端和 ADC 引脚参考面没有独立测量，
因此结果可计算，但正式结论保持“暂不能判定”。文件名中的
`error_input_vpp` 是采集 test_id；只有 manifest 的 capture/status 和数据
质量检查决定文件是否有效。

显式运行示例：

```matlab
result = adc_bandwidth_analysis(csvFolder, csvFiles, resultFolder);
result = adc_power_scale_analysis(csvFolder, csvFiles, resultFolder);
```

省略 `csvFiles` 时会处理 `csvFolder` 直属的全部 CSV。每次运行在指定
`resultFolder` 下新建时间戳目录，并输出 CSV、MAT、PNG、FIG、日志、状态和
含 SHA-256 的输入清单。
