# ADC128 带宽分析

运行 `128_hy/adc_bandwidth_analysis.m`，全部采集参数固化在 `128_hy/private/adc128Config.m`，无任何 GUI 弹窗或命令行问答：

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

文件名须包含注入频率（600Hz、1kHz 等）。混叠频率点的处理：

- **超过有效奈奎斯特**（如 55 kHz，混叠到 45 kHz）：保留并按文件名频率拟合，CodePp 为真实幅值（正弦的混叠像仍是严格正弦，幅值不失真；实测 55 kHz 与 45 kHz 拟合 CodePp 完全相等），但不参与 −3 dB 带宽计算（频率校验自动排除）。
- **恰在有效奈奎斯特点**（50 kHz = 100 kS/s / 2）：剔除。采样退化为交替码，幅值依赖触发相位，且 `sin(πn)` 基底数值退化，最小二乘会得出超量程伪值（实测某通道拟出 CodePp>22000）。

## 计算方法

与2208共用 `converter.adc.runBandwidth/calculateBandwidth`。先FFT估频，再优化正弦拟合频率，拟合 `a*sin(2*pi*f*t)+b*cos(2*pi*f*t)+c`；幅值 `CodePp=2*hypot(a,b)`，c 吸收直流偏置。读取时原始码减2048只做平移，不改峰峰值。

近轨检查支持上下轨独立门限（`clippingMarginLowCode/HighCode`，缺省回退共用 `clippingMarginCode`）。本入口下轨设 −1：2.5 Vpp/1.25 V 偏置恰好把波谷压在 0 码附近，触及/轻削 0 码的低频文件按既定判定**仍参与拟合**；上轨保留 1 码余量。参考幅值取最低 3 个有效点（600/800/1000 Hz）的 CodePp 中位数，响应为 `20*log10(CodePp/referenceCodePp)`；−3 dB 交点在 log10 频率轴上线性插值，覆盖不足不外推。输出为码值峰峰值与相对 dB，无 V/code 刻度不宣称电压单位。

结果沿用公共内核：`ADC_bandwidth_summary.csv`、`ADC_bandwidth_result.mat`、PNG/FIG、参数表、输入哈希和日志，写入时间戳 results 目录，原始数据不覆盖。无 ADC128 验收限值，正式结论为"暂不能判定"。

## 20260917 重分析结论（01_freq，5 通道，下轨放宽后）

| 通道 | −3 dB 带宽 | 有效点 | 参考 | 备注 |
|---|---|---|---|---|
| X10 | 31.07 kHz | 600 Hz～40 kHz 共 15 点 | 600/800/1000 Hz | 55 kHz 点保留 CodePp，不参与带宽 |
| X11_1 | 12.34 kHz | 同上 | 同上 | 同上 |
| X11-2 | 12.18 kHz | 同上 | 同上 | 同上 |
| X11-3 | 12.33 kHz | 同上 | 同上 | 同上 |
| X11-4 | 12.48 kHz | 同上 | 同上 | 同上 |

50 kHz 注入点恰在有效奈奎斯特点被剔除；55 kHz 点在结果表中给出 CodePp（真实幅值）。权威结果目录：`G:\513_CW_test\CW_Data\513_CW_DATA\20260917\ad128\01_freq\results\<通道>\run_20260917_123***_bandwidth\`（每通道取时间戳最大的一组；更早的 run 是本轮调试中间产物，策略不同勿引用）。
