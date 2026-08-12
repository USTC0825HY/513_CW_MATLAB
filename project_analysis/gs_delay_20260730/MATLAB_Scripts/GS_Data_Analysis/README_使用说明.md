# ADC 四项独立分析脚本使用说明

## 1. 文件说明

本目录包含四个彼此独立的入口文件：

| 文件 | 用途 |
|---|---|
| `adc_sfdr_analysis.m` | SFDR、SNR、SINAD、THD、ENOB |
| `adc_bandwidth_analysis.m` | 正弦拟合频率响应和 -3 dB 带宽 |
| `adc_isolation_analysis.m` | 多通道同频串扰隔离度 |
| `adc_power_scale_analysis.m` | 输入 dBm 与 ADC 码值/dBFS 标定 |

四个文件不会互相调用。它们只复用相邻 `sfdr` 目录中的
`analyze_adc_metrics.m` 和 `find_accu_peak.m`。

## 2. 最简单的使用方法

在 MATLAB 中将本目录设为当前文件夹，然后点击任意入口文件顶部的
“运行”。程序会在默认示例目录打开 CSV 多选窗口。

也可以在命令窗口执行：

```matlab
adc_sfdr_analysis
adc_bandwidth_analysis
adc_isolation_analysis
adc_power_scale_analysis
```

取消文件选择不会报错，程序会直接结束。

## 3. 指定目录批量运行

```matlab
scriptFolder = ...
    'F:\01_Laser\code\matlab\project_analysis\gs_delay_20260730\00_matlab';
addpath(scriptFolder);

% SFDR：指定目录后仍会弹窗选择文件
adc_sfdr_analysis( ...
    'F:\01_Laser\20260727_513test\02_GS与延迟驱动测试\02_Data_测试数据\513_GS_AD_DATA\AD9245\01_SFDR\X3G');

% 直接指定文件，不弹窗
adc_sfdr_analysis( ...
    'F:\01_Laser\20260727_513test\02_GS与延迟驱动测试\02_Data_测试数据\513_GS_AD_DATA\AD9245\01_SFDR\X3G', ...
    {'1MHZ.csv','5MHz.csv','7.5MHz.csv','10MHz.csv'});
```

其他三个入口的参数形式完全相同：

```matlab
results = adc_bandwidth_analysis(dataFolder, selectedFileNames);
results = adc_isolation_analysis(dataFolder, selectedFileNames);
results = adc_power_scale_analysis(dataFolder, selectedFileNames);
```

## 4. 更换 ADC 时修改什么

每个入口文件顶部都有“用户配置区”。一般只修改：

```matlab
sampleRate = 25e6;          % ADC 采样率，Hz
adcBits = 14;               % ADC 位数
adcCodeFormat = "signed";   % "signed" 或 "unsigned"
adcDataColumn = 0;          % 0 表示读取最后一列
```

程序自动计算：

```matlab
adcFullScalePeakCode = 2^(adcBits - 1);
```

典型满量程峰值码：

| ADC 位数 | 峰值码 |
|---:|---:|
| 12 bit | 2048 |
| 14 bit | 8192 |
| 16 bit | 32768 |

码值格式：

- `signed`：CSV 已经是以 0 为中心的有符号码值；
- `unsigned`：CSV 是 0 到 `2^N-1`，程序自动减去中点码；
- 如果配置位数与实际码值范围不一致，程序会给出警告。

## 5. 输入 CSV 要求

通用要求：

- 默认最后一列是 ADC 码值；
- 允许第一行包含 ILA 表头；
- ADC 数据列不能混入文字；
- 原始 CSV 不会被修改；
- 所有输出都进入输入目录下的 `results` 子目录。

文件名要求：

| 分析任务 | 文件名要求 |
|---|---|
| SFDR | 无强制要求，FFT 自动搜索基波 |
| 带宽 | 必须包含 Hz、kHz、MHz 或 GHz |
| 隔离度 | 文件名或文件头能识别 X1G～X4G |
| 功率标定 | 必须包含输入功率，如 `-10dBm.csv` |

## 6. 各脚本的专用参数

### SFDR

```matlab
nfft = 128 * 1024;
dcSpan = 16;
signalSpan = 16;
harmonicSpan = 8;
maxHarmonicOrder = 8;
```

### 带宽

```matlab
minimumFitR2 = 0.99;
referenceUpperFrequencyHz = 1e6;
```

`FitR2` 小于门限的文件保留在汇总表中，但不参与 -3 dB 带宽计算。

### 隔离度

```matlab
isolationFrequencyHz = 1e6;
drivenChannel = "X3G";
minimumIsolationDb = 40;
```

安静通道本身没有明显正弦信号，因此低 R² 不作为删除条件。

### 功率标定

```matlab
testFrequencyHz = 1e6;
powerRangeDbm = [-10 6];
clippingThreshold = 0.98;
clippingFractionLimit = 0.01;
plateauChangeThreshold = 0.01;
```

输出的是 ADC 码值响应和 dBFS 响应，不等同于 ADC 输入端的实际瓦特。

## 7. 示例数据实测结果

示例根目录：

```text
F:\01_Laser\20260727_513test\02_GS与延迟驱动测试\02_Data_测试数据\513_GS_AD_DATA\AD9245
```

### 7.1 X3G 动态指标

| 输入文件 | SFDR/dB | SNR/dB | SINAD/dB | THD/dB | ENOB/bit |
|---|---:|---:|---:|---:|---:|
| 1MHZ.csv | 68.638 | 68.219 | 64.841 | 67.503 | 11.357 |
| 5MHz.csv | 70.928 | 63.952 | 63.926 | 85.468 | 11.929 |
| 7.5MHz.csv | 67.276 | 60.632 | 60.389 | 72.898 | 11.924 |
| 10MHz.csv | 64.914 | 57.500 | 57.481 | 80.078 | 11.981 |

结果目录：

```text
SFDR_25MHz_6dBm\X3G\results
```

### 7.2 频率响应

```text
-3 dB 带宽 = 3.799983 MHz
```

不参与带宽计算的异常文件：

```text
5MHz.ila.csv：FitR2 ≈ 0.000001
10MHz.csv：FitR2 ≈ 0.52465
```

结果目录：

```text
freq_scale\X3G\results
```

### 7.3 隔离度

| 激励通道 | 安静通道 | 隔离度/dB | 40 dB 判定 |
|---|---|---:|---|
| X3G | X1G | 106.00 | 通过 |
| X3G | X2G | 102.84 | 通过 |
| X3G | X4G | 109.48 | 通过 |

最差隔离度为 102.835 dB。

结果目录：

```text
GeLiDu\X3G_1MHz_7dBm\results
```

### 7.4 输入功率标定

```text
通道：X3G
标定斜率：0.998387 dB/dBm
标定截距：-14.306572 dBFS
标定 R²：0.99999435
```

异常标记：

- `-2dBm.ila.csv`：与前一功率点形成平台；
- `6dBm.csv`：与 5 dBm 点形成平台；
- `10.8dBm.csv`：近满量程样本约占 4%，标记为削顶风险；
- 8、10、10.8 dBm 超出正式标定范围，只用于观察趋势。

结果目录：

```text
Power_Scale_1MHz\results
```

## 8. 输出文件

每项至少生成：

```text
ADC_*_summary.csv
ADC_*_result.png
ADC_*_result.fig
```

SFDR 还为每个输入文件生成独立频谱 PNG/FIG 和
`ADC_SFDR_log.txt`。

## 9. 常见问题

- 找不到公共模块：确认 `00_matlab` 与 `sfdr` 是相邻目录；
- 文件名无法解析：带宽文件写明 MHz/kHz，功率文件写明 dBm；
- 码值范围警告：检查 `adcBits` 和 `adcCodeFormat`；
- 图中出现异常点：先查看汇总 CSV 的 `FitR2`、`PlateauFlag`、
  `ClippingFlag`；
- 带宽没有 -3 dB 交点：需要增加更高频率的有效测试点；
- 隔离度安静通道 R² 很低：弱串扰条件下属于正常现象，应同时查看
  `QuietCodePp` 和残差。
