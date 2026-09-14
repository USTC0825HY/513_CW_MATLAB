# AD677 输入频率、输入功率与噪声分析

本目录提供 AD677 的四个入口：`adc_bandwidth_analysis.m`、
`adc_power_scale_analysis.m`、`adc_ila_noise_analysis.m` 和
`adc_pico_noise_1hz_analysis.m`。入口调用相邻公共内核，不包含 SFDR、
隔离度或 INL/DNL。

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
result = adc_ila_noise_analysis(csvFolder, csvFiles, resultFolder);
result = adc_pico_noise_1hz_analysis(matFolder, matFile, resultFolder, ...
    struct('interface', '677_1'));
```

省略 `csvFiles` 时在 `csvFolder` 弹窗选择本次CSV，可多选；不自动处理整目录。
零参数运行也会选择文件，取消正常退出且不创建结果目录。显式文件列表不弹窗，
相对文件名以csvFolder为准，也支持绝对路径。只选同接口、同条件的数据。

四个入口的函数签名均为 `(dataFolder,selectedFiles,outputFolder,runOptions)`。
第四参数支持本次配置覆盖；刻度还支持powerSetpoints。配置默认值在
`private/ad677Config.m`，采集点校验在private辅助文件中。这次文件选择修改未改变参数和公式。

未给输出目录时，一般在输入目录内部results；输入目录名为raw时，写入raw同级的results；
采集目录位于raw下一层时，沿用raw同级results布局。每次新建时间戳子目录，
历史结果保留。先看 `ADC_bandwidth_summary.csv` 或
`ADC_vpp_codepp_calibration.csv`、`ADC_critical_input_estimate.csv`，再看图、参数和输入清单。

切换到本目录前使用restoredefaultpath、clear functions，并用which核对同名函数。
保留private、相邻_shared及noise_chain_hy；原始数据只读。上述文件选择规则适用于四个单项入口，
677原有批处理和审计脚本未作修改。

## ILA噪声

ILA入口按CSV表头识别 `677_1/677_2`，不根据文件名猜通道。全部100 MHz抓取点
都参与Welch计算，包括 `adc_data_vld` 脉冲之间的保持码；第5列只统计有效脉冲数
和有效更新率。默认使用131072点Hann窗，统计1 Hz～10 kHz。100 MHz是ILA记录
时钟，不等于AD677有效转换更新率。当前没有正式噪声限值，结果为“暂不能判定”。
频带标线按实际数量级显示单位，因此上限标为 `10 kHz`，不会显示为 `0 MHz`。

噪声电压只在去均值后乘固定斜率，不使用截距：`677_1 = 1.536050e-4 V/code`，
`677_2 = 1.695154e-4 V/code`。这两个值直接保存在 `private/ad677Config.m`，
噪声入口不查公共报告刻度表或外部工作簿。

## PICO 1 Hz输入等效噪声

PICO入口按
`S_AD677 = S_PICO * [k_AD677/(|G_FPGA|*k_DA9726_JG18)]^2` 换算。
默认 `G_FPGA=128`，DA9726固定使用JG18斜率
`1.01451391294771e-4 V/code`，不扫描DAC结果CSV，也不扣除PICO或DAC本底。
采样率只从MAT中的 `Tinterval` 或 `fs` 读取。显式运行必须提供
`runOptions.interface`；文件名中的CH1/CH2不用于选择677接口。

默认目标分辨率为0.2 Hz、Hann窗、50%重叠，因此记录至少约5秒。当前
`ad677_noise_G128_CH1.mat` 只有约10 ms，入口会在创建结果目录前报记录时长不足；
补采长记录后仍使用同一入口。没有正式限值线，结果保持“暂不能判定”。

## 报告刻度配置

输入频率和输入功率入口的报告刻度由 `private` 配置加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。两个噪声入口只使用上面的器件固定斜率，不读取该报告刻度。
