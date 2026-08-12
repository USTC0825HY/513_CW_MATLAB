# ADC 四项独立分析脚本使用说明

## 1. 文件说明

本目录包含四个彼此独立的入口文件：

| 文件 | 用途 |
|---|---|
| `adc_sfdr_analysis.m` | SFDR、SNR、SINAD、THD、ENOB |
| `adc_bandwidth_analysis.m` | 正弦拟合频率响应和 -3 dB 带宽 |
| `adc_isolation_analysis.m` | 多通道同频串扰隔离度 |
| `adc_power_scale_analysis.m` | 输入 dBm 与 ADC 码值/dBFS 标定 |
| `adc_inl_dnl_analysis.m` | 正弦码密度法 DNL、INL |

四个文件不会互相调用。它们只复用安装包内部 `sfdr` 子目录中的
`analyze_adc_metrics.m` 和 `find_accu_peak.m`。

移动到其他目录或其他电脑时，必须复制整个 `00_matlab` 文件夹，
不能只复制四个入口文件。正确结构为：

```text
00_matlab
├─ adc_sfdr_analysis.m
├─ adc_bandwidth_analysis.m
├─ adc_isolation_analysis.m
├─ adc_power_scale_analysis.m
├─ adc_inl_dnl_analysis.m
├─ README_使用说明.md
└─ sfdr
   ├─ analyze_adc_metrics.m
   └─ find_accu_peak.m
```

入口会自动在当前目录、`sfdr` 子目录和 `lib` 子目录寻找公共算法，
不依赖原电脑上的绝对路径。

## 2. 最简单的使用方法

在 MATLAB 中将本目录设为当前文件夹，然后点击任意入口文件顶部的
“运行”。程序先要求选择数据目录，再弹出 CSV 多选窗口。数据目录
可以位于任意磁盘，不要求与代码目录保持相对位置。

也可以在命令窗口执行：

```matlab
adc_sfdr_analysis
adc_bandwidth_analysis
adc_isolation_analysis
adc_power_scale_analysis
adc_inl_dnl_analysis
```

取消文件选择不会报错，程序会直接结束。

## 3. 指定目录批量运行

```matlab
scriptFolder = ...
    'C:\Users\86183\Desktop\00_matlab';
addpath(scriptFolder);

% SFDR：指定目录后仍会弹窗选择文件
adc_sfdr_analysis( ...
    'F:\01_Laser\20260727_513test\02_GS与延迟驱动测试\02_Data_测试数据\513_GS_AD_DATA\AD9245\01_SFDR\X3G');

% 直接指定文件，不弹窗
adc_sfdr_analysis( ...
    'F:\01_Laser\20260727_513test\02_GS与延迟驱动测试\02_Data_测试数据\513_GS_AD_DATA\AD9245\01_SFDR\X3G', ...
    {'1MHZ.csv','5MHz.csv','7.5MHz.csv','10MHz.csv'});
```

其他入口的参数形式完全相同：

```matlab
results = adc_bandwidth_analysis(dataFolder, selectedFileNames);
results = adc_isolation_analysis(dataFolder, selectedFileNames);
results = adc_power_scale_analysis(dataFolder, selectedFileNames);
results = adc_inl_dnl_analysis(dataFolder, selectedFileNames);
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
| 带宽 | 建议包含 Hz、kHz、MHz 或 GHz；仅作期望频率记录 |
| 隔离度 | 文件名或文件头能识别 X1G～X4G |
| 功率标定 | 必须包含输入功率，如 `-10dBm.csv` |

### 实际频率判定规则

带宽、功率标定和隔离度脚本不会把文件名频率直接当作真实输入频率。
程序先对 ADC 码值进行 FFT，取得采样数据中的最大谱线频率，再使用这个
频率进行正弦拟合。文件名频率只保存在 `FileFrequencyHz` 或
`ExpectedFrequencyHz` 中，用于追溯和检查信号源是否按计划切换。

当实际频率与文件名频率的相对误差超过配置值时，汇总表中的
`FrequencyMismatchFlag` 为 1。默认门限为 2%。因此，文件名写成 5 MHz、
但实际采集到 10 MHz 的数据不会被错误地按 5 MHz 拟合，而会被标记为
频率不一致。

功率标定中的 dBm 仍必须从文件名或测试记录获得；ADC 码值本身不能反推出
信号源实际设置的 dBm，所以功率标签不能仅靠 FFT 自动确定。

INL/DNL 使用正弦码密度法，不依赖文件名频率。程序用第一份数据的 FFT
估计实际频率和正弦参数，再把所选 CSV 的码值合并统计；因此必须选择同一
通道、同一测试条件下的多份正弦采样文件。

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

### INL/DNL

```matlab
marginCode = 1000;        % 排除正弦两端低概率码区，LSB
minimumFitR2 = 0.99;      % 正弦拟合质量提示门限
```

该方法输出的是码密度法结果，DNL 和 INL 的具体可信度还取决于采样点数、
正弦幅度、直方图覆盖范围和输入信号稳定性。没有在此处强行设置 INL/DNL
合格限值。

## 7. 示例数据实测结果

本次复算数据根目录：

```text
F:\01_Laser\20260727_513test\02_GS与延迟驱动测试\02_Data_测试数据\513_GS_AD_DATA\AD9245
```

### 7.1 四通道动态指标汇总

| 通道 | 文件数 | SFDR 最小值/dB | SFDR 最大值/dB |
|---|---:|---:|---:|
| X1G | 5 | 64.660 | 78.232 |
| X2G | 4 | 63.014 | 68.611 |
| X3G | 4 | 64.914 | 70.928 |
| X4G | 4 | 66.864 | 72.815 |

结果目录：

```text
AD9245\<通道>\SFDR\results
```

### 7.2 频率响应

```text
-3 dB 带宽：X1G 4.892577 MHz；X2G 5.037173 MHz；
X3G 3.864047 MHz；X4G 3.965987 MHz
```

当前检测到的频率标记/拟合异常包括：

```text
X1G：1kHz 文件实际约 1.022kHz；5MHz 文件实际约 10MHz；
X2G：1kHz 文件实际约 1.022kHz；
X3G：1kHz 文件实际约 1.022kHz；5MHz 文件实际约 4MHz；
     10MHz 文件实际约 10MHz，但 FitR2 不合格；
X4G：1kHz 文件实际约 1.022kHz。
```

结果目录：

```text
AD9245\<通道>\FrequencyResponse\results
```

### 7.3 隔离度

| 激励通道 | 最差安静通道 | 最差隔离度/dB | 40 dB 判定 |
|---|---|---:|---|
| X1G | X4G | 92.604 | 通过 |
| X2G | X3G | 98.063 | 通过 |
| X3G | X4G | 97.735 | 通过 |
| X4G | X1G | 93.500 | 通过 |

四组激励数据的总体最差隔离度为 92.604 dB。

结果目录：

```text
AD9245\<激励通道>\Isolation\results
```

### 7.4 输入功率标定

本次四通道正式范围均为 -10～6 dBm。标定结果如下：

| 通道 | 斜率/dB/dBm | 截距/dBFS | R² |
|---|---:|---:|---:|
| X1G | 0.998760 | -14.269128 | 0.99999509 |
| X2G | 0.998900 | -14.327833 | 0.99999476 |
| X3G | 1.009650 | -14.644504 | 0.96769385 |
| X4G | 0.998639 | -14.303631 | 0.99999512 |

异常标记：X3G 的 10.8 dBm 文件接近满量程；X3G 的 `run02` 重复采集点被
标记为平台点，不参与正式标定；X4G 的 11 dBm 文件接近满量程且不在正式
范围内。X3G 的正式标定 R² 低于其他通道，使用前应检查重复采集和功率点
对应关系。

结果目录：

```text
AD9245\<通道>\InputPowerScale\results
```

### 7.5 INL/DNL

本次每个通道处理 60 个正弦采样文件，程序使用实际 FFT 频率进行正弦参数
估计，再进行码密度统计。结果如下：

| 通道 | 实际频率/MHz | 正弦拟合 R² | 最大 DNL/LSB | 最大 INL/LSB | 最大中段 INL/LSB |
|---|---:|---:|---:|---:|---:|
| X1G | 1.0123 | 0.99576 | 0.29677 | 8.1418 | 2.7403 |
| X2G | 1.0123 | 0.99578 | 0.30365 | 8.7092 | 2.6297 |
| X3G | 1.0123 | 0.99579 | 0.25511 | 6.4944 | 2.5015 |
| X4G | 1.0123 | 0.99579 | 0.24790 | 5.1397 | 5.1397 |

这些数值是当前配置（14 bit、25 MSPS、`marginCode = 1000`）下的码密度法
结果，报告中应同时注明测试限值和有效码值范围；当前脚本不擅自给出
“满足/不满足”结论。

结果目录：

```text
AD9245\<通道>\INL_DNL\results
```

## 8. 输出文件

每项至少生成：

```text
ADC_*_summary.csv
ADC_*_result.png
ADC_*_result.fig
```

INL/DNL 还生成 `ADC_inl_dnl_curve.csv`，保存每个码值的实测概率、理论
概率、DNL 和 INL。SFDR 还为每个输入文件生成独立频谱 PNG/FIG 和
`ADC_SFDR_log.txt`。

## 9. 常见问题

- 找不到公共模块：确认复制了整个 `00_matlab` 文件夹，且
  `00_matlab\sfdr` 中存在 `analyze_adc_metrics.m` 和
  `find_accu_peak.m`；
- 移动电脑后数据路径失效：直接无参数运行并重新选择数据目录，
  或通过函数第一个参数传入新电脑上的数据目录；
- 文件名无法解析：带宽文件写明 MHz/kHz，功率文件写明 dBm；
- 码值范围警告：检查 `adcBits` 和 `adcCodeFormat`；
- 图中出现异常点：先查看汇总 CSV 的 `FitR2`、`PlateauFlag`、
  `ClippingFlag`；
- 带宽没有 -3 dB 交点：需要增加更高频率的有效测试点；
- 隔离度安静通道 R² 很低：弱串扰条件下属于正常现象，应同时查看
  `QuietCodePp` 和残差。
## Windows 7 / MATLAB R2018 中文与兼容性

本目录中的四个入口脚本及 `sfdr` 下两个公共算法文件已经保存为
`UTF-8 with BOM`。BOM 用于让旧版 MATLAB 明确识别中文源码编码，复制到
其他电脑时不依赖系统的 ANSI/GBK 代码页。

同时已经将 MATLAB R2018 不支持或版本风险较高的接口替换为兼容写法：

- `arguments` 改为普通输入检查；
- `readmatrix` 改为 `importdata`；
- `tiledlayout/nexttile` 改为 `subplot`；
- `exportgraphics` 改为 `print`；
- `xline/yline` 改为普通 `plot` 参考线；
- Hann 窗使用公式直接生成，不要求额外工具箱。

复制到另一台电脑时，必须复制整个 `00_matlab` 文件夹，不能只复制一个
入口 `.m` 文件。四个入口会自动从随包的 `sfdr` 子目录寻找
`analyze_adc_metrics.m` 和 `find_accu_peak.m`。

如果用第三方编辑器修改文件，请继续保存为 `UTF-8 with BOM`，不要保存成
ANSI。若图中的中文仍显示为方框，这是字体问题而不是编码问题，可在绘图
代码中指定 Windows 7 自带字体，例如：

```matlab
set(gca, 'FontName', 'SimSun');
```

## 数据目录规范

新数据根目录采用以下结构：

```text
513_GS_AD_DATA
└─ <Device>
   └─ <Metric>
      └─ <Channel>
         ├─ raw
         └─ results
```

AD9245 的 X3G 示例路径为：

```text
AD9245\01_SFDR\X3G\raw
AD9245\02_FrequencyResponse\X3G\raw
AD9245\03_InputPowerScale\X3G\raw
AD9245\04_Isolation\X3G\raw
AD9245\05_INL_DNL\X3G\raw
```

调用示例：

```matlab
dataRoot = 'F:\...\513_GS_AD_DATA';
adc_sfdr_analysis(fullfile(dataRoot, 'AD9245', '01_SFDR', 'X3G', 'raw'));
adc_bandwidth_analysis(fullfile(dataRoot, 'AD9245', '02_FrequencyResponse', ...
    'X3G', 'raw'));
adc_power_scale_analysis(fullfile(dataRoot, 'AD9245', '03_InputPowerScale', ...
    'X3G', 'raw'));
adc_isolation_analysis(fullfile(dataRoot, 'AD9245', '04_Isolation', ...
    'X3G', 'raw'));
adc_inl_dnl_analysis(fullfile(dataRoot, 'AD9245', '05_INL_DNL', ...
    'X3G', 'raw'));
```

当输入目录最后一级是 `raw` 时，脚本会自动把结果写入同级的
`results` 目录。也可以显式指定第三个参数：

```matlab
results = adc_bandwidth_analysis(rawFolder, [], resultFolder);
```

`00_Metadata\measurement_manifest.csv` 记录原始文件名、目标路径、器件、
指标、通道、测试条件和 SHA-256；`result_manifest.csv` 记录各指标的结果
目录、汇总文件和处理脚本。原始 CSV 不修改；历史结果文件不放入 `raw`。

AD9245 的旧“通道优先”目录已归档到：

```text
513_GS_AD_DATA\99_Archive\AD9245_ChannelFirst_20260802
```

迁移后的目录由“器件 -> 指标 -> 通道 -> raw/results”组成，便于同一指标
下横向比较 X1G～X4G，也便于后续增加其他器件的同名指标。

当前 AD9245 数据目录还包含 `INL_DNL` 测试数据。原四个频域入口不处理这类
数据，因此这些 CSV 不会套用 SFDR 或带宽算法。当前已增加独立的
`adc_inl_dnl_analysis.m`，采用正弦码密度法处理；它的结果应结合测试细则
确认，不与 SFDR、带宽或功率标定结果混用。

数据目录迁移工具为：

```text
..\migrate_ad9245_metric_first.ps1
```

本次 AD9245 目录迁移已执行并完成 379 个原始文件的 SHA-256 校验。若需要
在另一份同结构数据上执行，应先确认目标目录中不存在同名的新结构，再执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\migrate_ad9245_metric_first.ps1 `
  -DataRoot 'F:\...\513_GS_AD_DATA'
```

该工具先复制并校验文件，再将旧的通道优先目录移动到
`99_Archive\AD9245_ChannelFirst_20260802`；不会删除或修改原始 CSV。
