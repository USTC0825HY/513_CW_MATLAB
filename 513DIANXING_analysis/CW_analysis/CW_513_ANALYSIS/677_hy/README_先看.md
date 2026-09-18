# AD677 输入频率、输入功率与噪声分析

本目录提供 AD677 的四个正式入口：`adc_bandwidth_analysis.m`、
`adc_power_scale_analysis.m`、`adc_ila_noise_analysis.m` 和
`adc_pico_noise_1hz_analysis.m`。入口调用相邻公共内核，不包含 SFDR、
隔离度或 INL/DNL。另有通用快速查看入口 `ila_waveform_fft.m` /
`run_ila_waveform_fft.m`（任意 CSV 的波形+FFT 单图分析，见下文专节）。

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

省略 `csvFiles` 时，**带宽入口**直接自动扫描 `csvFolder` 内全部CSV（不弹窗）；无参数
运行才弹多选对话框。其余三个入口仍为：省略 `csvFiles` 时弹窗多选，不自动处理整目录。
零参数运行取消正常退出且不创建结果目录。显式文件列表不弹窗，相对文件名以csvFolder
为准，也支持绝对路径。只选同接口、同条件的数据。

## 通用波形 + FFT 快速查看（ila_waveform_fft / run_ila_waveform_fft）

独立通用工具，不依赖 Signal Processing Toolbox，用于任意带表头 CSV 的
“波形 + 单边幅值谱”单图快速查看；与上面四个正式入口互不影响，也不读
`private/ad677Config.m`。

```matlab
run_ila_waveform_fft                                    % GUI：CSV 多选 + 输出目录
run_ila_waveform_fft(files)                             % 批量：默认输出目录
run_ila_waveform_fft(files, 'D:\out')                   % 批量：指定输出目录
run_ila_waveform_fft(files, 'D:\out', struct('window','blackmanharris'))
r = ila_waveform_fft(csv, struct('signalColumn','adc1_data', ...
    'validColumn','adc1_valid', 'toneMarkersHz',[20.833e3 41.667e3]))
```

要点：

- `run_` 入口自动识别 CSV 内全部 `adc*data` 信号列并与 valid 列配对
  （兼容 `adc1_data[15:0]+adc1_valid` 双驱动格式和
  `u_ad677_2/adc_data[15:0]+u_ad677_2/adc_data_vld` 单通道旧格式），逐信号
  做**选通重采样**分析：有效采样率从实测选通间隔推导（如 1200 拍 →
  83.333 kS/s）并校验均匀性；找不到 valid 列时退回 raw @ILA 时钟并告警。
- `ila_waveform_fft` 也支持普通均匀采样 CSV（`sampleRateHz`）、十六进制补码
  列（`codeFormat='signed16'`）、`voltsPerCount` 换伏特、6 种内置窗、对数谱。
- 默认开启 `autoToneMarkers`：自动检测码序列重复周期 P（仅选通模式），在频谱
  标出 k·fs/P 谱线。20260917 双驱动噪声采集实测：tc 路 P=4 → 20.833/41.667 kHz，
  mnyc 路 P=3 → 7.199/14.399 kHz。
- 输出命名为 `<CSV文件名>__<信号列名>.png/.mat` 与 `...__spectrum.csv`；同一 run
  目录内重复分析自动追加 `__1`、`__2`，永不覆盖。
- **输出布局（20260917 起）**：与四个正式入口同约定——绝不写进数据目录本身。
  每次调用在结果基目录下新建时间戳子目录 `run_<yyyyMMdd_HHmmss>_ila_fft`
  （一次批量调用共享同一时间戳目录）。结果基目录按数据目录位置解析：数据在
  `raw` 内 → `raw` 同级 `results`；数据在 `raw` 下一层 → 同样用该 `raw` 同级
  `results`；其他情况 → 数据目录内部 `results`。GUI 的目录对话框选的是**基目录**
  （默认就停在解析出的 results 位置），取消则用默认基目录。图幅强制白底，
  不随 MATLAB 深色主题变黑。
- 证据边界：脚本只做数字信号处理，不推断物理参考面；`voltsPerCount` 由调用方
  负责；选通间隔不均匀时频谱仅作参考（有告警）。

## 带宽（20260917起 v0.2.0）

ILA 以 100 MHz 记录，但 `adc_data` 只在 `adc_data_vld`（第5列）选通时更新——20260917
采集实测每 1200 个ILA周期选通一次，即有效数据率 100 MHz/1200 = 83.333 kS/s，每文件
约 109 个有效样本。带宽入口自动从选通间隔推导该速率并校验均匀性，读取时剔除保持码
（共享内核按 `filterValidStrobe=true` 显式开启，噪声/功率刻度入口不受影响）。

记录内周期数门限 `minimumRecordCycles=2`：100 Hz～1 kHz 各文件仅覆盖 0.13～1.31 个
周期，部分弧段的正弦拟合会以完美 R² 返回错误幅值（100 Hz 实测虚高 11%），因此剔除；
参考幅值取 2/4/6 kHz 的 CodePp 中位数。`minimumFitR2=0.90` 是为容纳 AD677 高频端真实
失真（30 kHz 实测 R²≈0.94），使 20/22/24 kHz 点保留在 −3 dB 交点插值内。超过有效奈奎
斯特（41.7 kHz）的频点按文件名频率拟合仍给出真实 CodePp 但不参与带宽计算；恰在奈奎
斯特点的频点剔除。

**结果目录**：带宽入口默认写入数据目录同级的 `results`（不在数据目录内部，也不在
raw 上级）；例如数据 `...\01_freq\raw\ad677_ch01_...` → 结果 `...\01_freq\raw\results\`。

20260917 ch01 1 Vpp 扫频：2k～30k 共 15 点全部有效，−3 dB 带宽 **20.87 kHz**
（参考 CodePp 中位数 5378.7，2/4/6 kHz）。1.5 Vpp 扫频：15 点全部有效，
−3 dB 带宽 **20.49 kHz**（参考 CodePp 中位数 8353.4，幅值比 1 Vpp 高约 1.55 倍，
与 1.5 倍输入及轻微压缩一致）。两轮权威结果为 `...\01_freq\raw\results\` 下
`run_20260917_131155_bandwidth`（1 Vpp）与 `run_20260917_131139_bandwidth`（1.5 Vpp）。

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
