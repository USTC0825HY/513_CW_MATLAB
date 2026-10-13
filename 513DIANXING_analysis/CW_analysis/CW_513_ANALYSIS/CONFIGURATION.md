# 参数配置使用说明

2026-10-02：六器件配置整理，26个单项入口保留。当轮计算公式、筛选阈值和默认增益保持原值；刻度来源于2026-10-12更新为按板型选择。

## 日常使用

1. 在需要的器件目录运行单项入口，先核对 `which 函数名 -all`，不要对整个库使用genpath。
2. 长期设置改对应private配置分支；单次设置通过入口已有参数传入。
3. 文件位置参数非空时优先；未填写的算法参数沿用默认。
4. 参数拼错报错；备注放metadata。已知停用字段会提示不生效。
5. 看结果目录的精简工作簿，再看evidence中的最终配置和状态。直流输出电压入口仍保持独立CSV/PNG布局。

## 两个最常见的覆盖例子

```matlab
% 在9245_hy目录：25 MHz历史采集，每5点保留1点；分析速率自动为5 MHz。
opt = struct('sampleRate',25e6,'inputRadix','hex'); % hex必须符合实际导出设置
r = adc_sfdr_analysis(d,files,out,opt);

% 在9245_hy目录：显式切换为dBm拟合范围。
opt = struct('powerRangeVpp',[],'powerRangeDbm',[-10,6],'inputRadix','decimal');
r = adc_power_scale_analysis(d,files,out,opt);

% 在9726_hy或766_hy目录：没有外部放大的噪声记录，只改本次增益。
r = dac_noise_analysis(d,files,out,struct('hardwareGain',1,'dataVariables',{{'A'}}));
```

常规ADC可使用直接字段或 `runOptions.configOverride`，不能把算法字段同时放在两层。两个DAC的第四参数是configOverride本身；766 hex第四参数是频率数值；2208 INL第四参数是连续性布尔值、第五参数才是runOptions。完整历史配置中的已知字段兼容；未知自定义字段需放入metadata。

## 入口到配置分支

| 器件 | 单项入口 | private分支 | 调用说明 |
|---|---|---|---|
| 2208 | `adc_bandwidth_analysis.m` | `bandwidth` | 第四参数为本次配置覆盖 |
| 2208 | `adc_ila_noise_analysis.m` | `input_noise` | 第四参数为本次配置覆盖 |
| 2208 | `adc_inl_dnl_analysis.m` | `inl_dnl` | 第四参数为记录连续性布尔值，第五参数为runOptions |
| 2208 | `adc_isolation_analysis.m` | `isolation` | 第四参数为本次配置覆盖 |
| 2208 | `adc_pico_noise_1hz_analysis.m` | `pico_noise` | 第四参数为本次配置覆盖 |
| 2208 | `adc_power_scale_analysis.m` | `power_scale` | 第四参数为本次配置覆盖 |
| 2208 | `adc_sfdr_analysis.m` | `sfdr` | 第四参数为本次配置覆盖 |
| 9245 | `adc_bandwidth_analysis.m` | `bandwidth` | 第四参数为本次配置覆盖 |
| 9245 | `adc_inl_dnl_analysis.m` | `inl_dnl` | 第四参数为本次配置覆盖 |
| 9245 | `adc_input_noise_analysis.m` | `pico_noise` | 三参数：数据目录、输出目录、runOptions；文件放selectedFiles |
| 9245 | `adc_isolation_analysis.m` | `isolation` | 第四参数为本次配置覆盖 |
| 9245 | `adc_power_scale_analysis.m` | `power_scale` | 第四参数为本次配置覆盖 |
| 9245 | `adc_sfdr_analysis.m` | `sfdr` | 第四参数为本次配置覆盖 |
| 677 | `adc_bandwidth_analysis.m` | `bandwidth` | 第四参数为本次配置覆盖 |
| 677 | `adc_ila_noise_analysis.m` | `input_noise` | 第四参数为本次配置覆盖 |
| 677 | `adc_pico_noise_1hz_analysis.m` | `pico_noise` | 第四参数为本次配置覆盖 |
| 677 | `adc_power_scale_analysis.m` | `power_scale` | 第四参数为本次配置覆盖 |
| 128 | `adc_bandwidth_analysis.m` | `bandwidth` | 第四参数为本次配置覆盖 |
| 9726 | `dac_isolation_analysis.m` | `isolation` | 第四参数为本次配置覆盖 |
| 9726 | `dac_noise_analysis.m` | `noise` | 第四参数为本次配置覆盖 |
| 9726 | `dac_output_voltage_analysis.m` | `output_voltage` | 第四参数为本次配置覆盖 |
| 9726 | `dac_scale_analysis.m` | `scale` | 第四参数为本次配置覆盖 |
| 766 | `dac_isolation_analysis.m` | `isolation` | 第四参数为本次配置覆盖 |
| 766 | `dac_noise_analysis.m` | `noise` | 第四参数为本次配置覆盖 |
| 766 | `dac_scale_analysis.m` | `scale` | 第四参数为本次配置覆盖 |
| 766 | `dac_scale_hex_analysis.m` | `scale_hex` | 第四参数为数值toneFrequencyHz；省略使用1525 Hz |

## 当前关键参数与边界

### 2208

- `sfdr/bandwidth/power_scale/isolation/inl_dnl/input_noise`仍对应原单项分析；新增 `pico_noise` 集中保存PICO参数。
- ILA噪声保持100 MHz、单段、NFFT=131072、10～25 MHz；PICO保持FPGA增益128、Hann、目标频点间隔0.2 Hz、50%重叠，DA9726 JG18 按本次所选板型取值。
- 隔离度当前默认驱动为ADC5_JG22；带宽当前R²下限0.95。正式判定开关现已显式填写，未改变原来的判定行为。

### 9245

- 修改SFDR原始采样率后，分析采样率自动按 `sampleRate/sfdrSampleStride` 计算。旧25 MHz数据只需覆盖 `sampleRate=25e6`，默认步长5得到5 MHz。若显式提供分析采样率，必须一致。
- 当前刻度启用 `powerRangeVpp=[0.1,2.1]`。要切换dBm范围，必须同时传 `powerRangeVpp=[]`，例如 `struct('powerRangeVpp',[],'powerRangeDbm',[-10,6])`。只改dBm范围却保留Vpp范围会报错。
- PICO噪声默认值集中在 `private/ad9245Config.m` 的 `pico_noise` 分支；仍用三参数调用。DA9726 JG18 按板型配套选择。
- 未新增R²或频率偏差排除条件，99%临界输入方法不变。`adcDataColumn=0`明确表示最后一列。

### 677

- ILA 与 PICO 噪声参数分别在对应分支；ADC、DAC 刻度按板型从公共报告表选择，见 CALIBRATION.md。
- 2026-10-12按两份报告补录频率与拟合点数：鉴定件两路各10点，加强件677_1为10点、677_2为9点；报告表未列的R²保持为空。软件回归与板级刻度测量分别记录。
- ILA保持100 MHz和131072点，记录1.31072 ms、频点间隔762.939453125 Hz。请求1～10000 Hz时，实际频带内频点约762.939～9918.213 Hz，不能评价1 Hz；控制台会提示，`evidence/*_frequency_coverage.mat`记录实际覆盖。
- PICO仍用足够长的MAT记录、增益128和目标0.2 Hz；正式条件未确认，维持“暂不能判定”。

### 128

- 仍为12位unsigned，数据列5、valid列4、ILA时钟50 MHz；`sampleRate=NaN`表示按选通间隔推导，显式有限采样率表示调用者覆盖。
- 下沿 `clippingMarginLowCode=-1` 保留；33 Ω和50 Ω只是源阻抗说明，默认不自动乘83/33。不要把修改电阻字段当成已经启用了带宽换算。

### 9726

- `scale/noise/isolation/output_voltage`分别配置正弦刻度、噪声、隔离度和直流输出；正弦刻度增益1，噪声增益100。
- PICO真实采样率逐文件读取Tinterval/fs。配置中的250 kHz或历史39.0625 MHz不是本次实测采样率，修改它不会改变MAT时基。
- 隔离度默认两路共同增益1；显式指定其他共同增益会保留，两路幅值比中的共同增益抵消。当前不支持两路不同放大倍数。
- 直流输出默认边沿阈值0.25 V、最短保持0.05 s、平台容差0.02 V、平滑窗口201点；第四参数options按字段覆盖，原空值沿用默认。

### 766

- `scale`是普通十进制刻度，`scale_hex`是十六进制专用刻度，`noise`是噪声，`isolation`是隔离度。各分支只列相关参数。
- 十六进制刻度的1525 Hz、增益1、512～65536码幅范围已集中到 `private/da766Config.m` 的 `scale_hex` 分支。入口第四参数仍是数值频率，例如 `dac_scale_hex_analysis(d,files,out,1525)`，不是struct。
- 噪声仍是增益100、Hann、目标0.2 Hz、50%重叠、1～100 kHz积分；停用的resolutionAuditRequired不是实际开关。覆盖判断由目标间隔、段数和频点偏差控制。

## 开发与验证

新参数先加入对应private分支，再在运行边界补充校验；条件可选字段和旧配置字段登记在 `converter.runtime.knownConfigFields`。通用 `mergeConfig` 仍只做顶层合并，入口使用 `finalizeConfig`。新增参数需测试默认、覆盖、错误值及旧调用兼容，不在report层重写公式。

`parameterSources`记录默认/覆盖/派生来源；PICO实际采样率始终以MAT为准。677新增频带覆盖说明不改变频谱或阈值。ADC正式判定与releaseReady分别记录。历史结果不迁移。

本次证据、配置差异及验收结果见 [配置优化报告](docs/20261002_private_config/REPORT.md)，完整26入口签名见 [入口矩阵](docs/20261002_private_config/ENTRY_CONFIG_MATRIX.csv)。

## 按板型选择刻度（2026-10-12）

鉴定件和电性加强件使用各自报告的刻度表。需要刻度的噪声入口在交互运行时询问板型，每次重新选择；显式传文件时填写 `boardType='jianding'`（鉴定件）或 `'jiaqiang'`（电性加强件）。

`calibrationState='current'` 优先使用该接口的改焊后记录；仅有一条记录时沿用该记录及其原状态。`'before'`、`'after'` 用于明确要求对应版本；该接口没有所选版本时会列出可用版本并结束。

长期刻度统一维护在 [`report_calibrations_20261004.csv`](_shared/+converter/+calibration/report_calibrations_20261004.csv)。private 只保存分析参数。逐行数值、来源和自定义刻度示例见 [CALIBRATION.md](CALIBRATION.md)。

运行时显示实际板型、接口、版本和斜率；打开 `结果汇总.xlsx` 查看简短刻度说明，完整记录在 `evidence` 的配置/结果 MAT 与刻度 CSV 中。单位为 **V/code**；噪声去均值后仅使用斜率，截距不参与噪声换算。历史结果保持原样。
