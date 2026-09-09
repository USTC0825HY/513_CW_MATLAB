# AD677 输入频率与输入功率分析

本目录只提供 AD677 的两个入口：`adc_bandwidth_analysis.m` 和
`adc_power_scale_analysis.m`。二者调用相邻 `_shared/+converter/+adc`
中的公共算法，不包含 SFDR、隔离度或 INL/DNL。

采集证据为 16 位 signed two's-complement 十进制码，ADC 数据位于 CSV
第 4 列，第 5 列为 `adc_data_vld`；ILA 以 100 MHz 记录，转换码在有效脉冲
之间保持。通道由 CSV 头的 `u_ad677_1/2` 映射为 `677_1/677_2`。

输入功率刻度严格拟合 `Vpp = a*CodePp + b`，横轴 CodePp、纵轴 Vpp。
manifest 表明信号源为 SDG6032X-E 且输出模式为 High-Z；这里的 Vpp 是
信号源显示设置值。板连接器、实际终端和 ADC 引脚参考面没有独立测量，
因此结果可计算，但正式结论保持“暂不能判定”。文件名中的
`error_input_vpp` 是采集 test_id；只有 manifest 的 capture/status 和数据
质量检查决定文件是否有效。

功率刻度会用未削顶点分别拟合正、负峰值轨，并估计任一轨首先达到99%数字
满量程时的输入 Vpp。当前扫描没有削顶点时，结果必须标记为
`unbracketed_extrapolation`，同时输出相对实测上限的外推倍数；图中使用空心
菱形和虚线，并注明“需补扫验证”。该估计不改变 `formalEnabled=false`。

显式运行示例：

```matlab
result = adc_bandwidth_analysis(csvFolder, csvFiles, resultFolder);
result = adc_power_scale_analysis(csvFolder, csvFiles, resultFolder);
```

省略 `csvFiles` 时在 `csvFolder` 弹窗选择本次CSV，可多选；不自动处理整目录。
零参数运行也会选择文件，取消正常退出且不创建结果目录。显式文件列表不弹窗，
相对文件名以csvFolder为准，也支持绝对路径。只选同接口、同条件的数据。

两个入口的函数签名均为 `(dataFolder,selectedFiles,outputFolder,runOptions)`。
第四参数支持本次配置覆盖；刻度还支持powerSetpoints。配置默认值在
`private/ad677Config.m`，采集点校验在private辅助文件中。这次文件选择修改未改变参数和公式。

未给输出目录时，一般在输入目录内部results；输入目录名为raw时，写入raw同级的results；
采集目录位于raw下一层时，沿用raw同级results布局。每次新建时间戳子目录，
历史结果保留。先看 `ADC_bandwidth_summary.csv` 或
`ADC_vpp_codepp_calibration.csv`、`ADC_critical_input_estimate.csv`，再看图、参数和输入清单。

切换到本目录前使用restoredefaultpath、clear functions，并用which核对同名函数。
保留private及相邻_shared；原始数据只读。上述文件选择规则适用于两个单项入口，
677原有批处理和审计脚本未作修改。

## 报告刻度配置

本器件的报告刻度由 `private` 配置中的 `reportCalibration` 字段加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。
