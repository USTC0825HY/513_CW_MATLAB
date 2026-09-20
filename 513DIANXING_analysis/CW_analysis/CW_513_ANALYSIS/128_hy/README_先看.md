# ADC128 带宽分析

运行 `128_hy/adc_bandwidth_analysis.m`，默认采集参数在 `128_hy/private/adc128Config.m`；
零参数会弹文件选择框。CSV进制缺少声明时，交互运行还会要求确认进制：

- `ilaClockHz = 50e6`：ILA 记录时钟。
- `adcDataColumn = 5`：CSV 第 5 列 `data_128[11:0]`，12 bit unsigned 原始码 0～4095。第 4 列是 `data_128_vld` 选通标志，不是码值。
- `validDataColumn = 4`：只保留 vld=1 的行。ILA 以 50 MHz 记录，但数据每 500 个 ILA 周期才更新一次（20260917 采集实测），其余行为保持码，必须剔除。
- `sampleRate = NaN`：每次运行从 vld 选通间隔自动推导有效数据率（50 MHz/500 = 100 kS/s），并校验所有文件选通周期一致、间隔均匀；如需强制覆盖，可经 runOptions 传入有限 `sampleRate`。

## 调用方式

无参数调用会弹出文件选择对话框，**可多选**同一通道的扫频 CSV（参数仍全部来自 config，不再询问采样率和列号）：

```matlab
addpath('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/128_hy');
r = adc_bandwidth_analysis;    % 弹GUI多选CSV，取消则返回空表
```

批处理/显式调用（不弹任何窗口）：

```matlab
r = adc_bandwidth_analysis( ...
    'G:/513_CW_test/CW_Data/513_CW_DATA/20260917/ad128/01_freq/raw/adc128_X10_2.5Vpp_frequency_sweep_20260917_104354_587354', ...
    [], ...                                  % 空则自动扫描目录内全部CSV
    'G:/.../01_freq/results/<通道名>');        % 输出目录（可省略，默认数据目录下results）
```

文件名须包含注入频率（600Hz、1kHz 等）。当前处理规则：

- **超过有效Nyquist**（例如100 kS/s采样的55 kHz注入）：保留明细，按FFT估计并优化得到的采样域频率拟合，不能把混叠频率当成新的注入频率；该点不参与 −3 dB 带宽。
- **恰在有效Nyquist**：也保留明细，但不参与带宽。此时正弦幅值依赖采样相位，不能只因R²好就采信。
- 表内 `NyquistOrAboveFlag`、`IllConditionedFitFlag`、`InsufficientCyclesFlag` 分别提示混叠范围、病态拟合或超码域幅值、少于两周期。所有数值都需连同这些标记查看。

显式传文件时，按真实导出进制设置，例如：

```matlab
options = struct('inputRadix','hex'); % 确认本批ILA导出为十六进制
r = adc_bandwidth_analysis(dataFolder, files, [], options);
```

`inputRadix` 可用hex、decimal、auto。auto只采用明确声明等证据，无法判断时不会猜测。
实际采用的进制、列号、点数记录在 `evidence/input_decoding.csv`。12位unsigned表示码域0～4095，不表示CSV一定是十进制。

## 源阻抗说明与截止频率换算（v0.3.1 起）

两条输入链路的前级 R 不同，**脚本输出为实测带宽**，不做自动修正：

- **IN1（X10）**：OP27 差分缓冲驱动，源阻抗≈0，R=板级 33Ω；
- **IN2–IN5（X11-1/2/3/4/5）**：信号源直连，SDG6000 源内阻 50Ω 与板级 33Ω（R318–R322）串联，R=83Ω。

X11 通道的板级截止频率由工程师自行换算（结果图表按实测扫频展示）：

```
fc_板级 = fc_实测 × (33+50)/33 ≈ fc_实测 × 2.5152
```

交叉验证：X11 实测 12.18–12.48 kHz ×2.5152 ≈ 30.6–31.4 kHz，与 X10 实测 31.07 kHz（同为板级 33Ω+150nF）吻合。如需自动去嵌，`adc128Config.m` 中 `bandwidthScaleRules` 的注释行可恢复启用。

## 计算方法

与2208共用 `converter.adc.runBandwidth/calculateBandwidth`。先FFT估频，再优化正弦拟合频率，拟合 `a*sin(2*pi*f*t)+b*cos(2*pi*f*t)+c`；幅值 `CodePp=2*hypot(a,b)`，c 吸收直流偏置。读取时原始码减2048只做平移，不改峰峰值。

近轨检查支持上下轨独立门限（`clippingMarginLowCode/HighCode`，缺省回退共用 `clippingMarginCode`）。本入口下轨设 −1：2.5 Vpp/1.25 V 偏置恰好把波谷压在 0 码附近，触及/轻削 0 码的低频文件按既定判定**仍参与拟合**；上轨保留 1 码余量。参考幅值取最低 3 个有效点（600/800/1000 Hz）的 CodePp 中位数，响应为 `20*log10(CodePp/referenceCodePp)`；−3 dB 交点在 log10 频率轴上线性插值，覆盖不足不外推。输出为码值峰峰值与相对 dB，无 V/code 刻度不宣称电压单位。

新结果写入独立时间戳目录。外层为 `结果汇总.xlsx` 和PNG；`evidence` 内保存
`ADC_bandwidth_summary.csv`、`ADC_bandwidth_result.mat`、FIG、参数、输入哈希和日志。
先看工作簿及标记，再看图；原始数据和历史结果不覆盖。无ADC128验收限值，正式结论为“暂不能判定”。

## 20260917 重分析结论（01_freq，5 通道，下轨放宽后）

以下为当时配置下的历史结果。当前源码已有输入解析与质量标记更新，这些数值不是本次重跑结论。

| 通道 | −3 dB 带宽 | 有效点 | 参考 | 备注 |
|---|---|---|---|---|
| X10 | 31.07 kHz | 600 Hz～40 kHz 共 15 点 | 600/800/1000 Hz | 55 kHz 点保留 CodePp，不参与带宽 |
| X11_1 | 12.34 kHz | 同上 | 同上 | 同上 |
| X11-2 | 12.18 kHz | 同上 | 同上 | 同上 |
| X11-3 | 12.33 kHz | 同上 | 同上 | 同上 |
| X11-4 | 12.48 kHz | 同上 | 同上 | 同上 |

上述历史处理未让50 kHz/55 kHz点参与带宽。历史结果目录为
`G:\513_CW_test\CW_Data\513_CW_DATA\20260917\ad128\01_freq\results\<通道>\run_20260917_123***_bandwidth\`。
引用时核对目录中的实际参数、状态和原始数据哈希，不仅按时间戳选择。
