# DA9726 分析脚本使用说明

更新：2026-09-16。

在 MATLAB 编辑器中打开对应脚本并点击 Run，也可以在命令窗口输入函数名。不带参数运行时，按弹窗选择原始文件。程序只处理选中的文件；在文件、接口或测量条件对话框中取消，均不生成结果。

换器件时先在命令窗口执行：

```matlab
restoredefaultpath;
clear functions;
cd('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/9726_hy');
dataRoot = 'F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA';
```

不同器件有同名函数，用 `which 函数名 -all` 检查调用路径。不要用 `genpath` 加载整个库。运行时需要本器件的 `private` 和相邻的 `_shared`；2208/9245 PICO 噪声还需要 `noise_chain_hy`。这些依赖由入口加载，不用单独运行。

## 输入文件与结果目录

- CSV 项目选择原始 CSV；PICO/DAC 项目选择原始 MAT。汇总 CSV、结果 MAT 和配对清单不是原始波形。
- 只传数据目录而不传文件列表时，在该目录打开选择框，不扫描整个目录。默认目录也只用作选择框的起始位置。
- 相对文件名以给定的数据目录为准；也支持绝对路径。传入非空文件列表或有效配对清单时直接运行，不弹选择框。
- 不改写原始数据。省略输出目录时，输入目录名为 `raw` 就写到它旁边的 `results`，否则写到该目录内的 `results`。
- 每次创建新的 `run_日期_时间_项目` 子目录；同一秒再次运行会加序号。命令窗口打印完整路径，历史结果保留。
- 重复文件或会生成同名图谱的文件会报错，避免相互覆盖。通道、参考面、增益和负载以测量记录为准，文件名不能代替这些记录。

## 脚本与数据

| 分析项目 | 运行脚本 | 选择的数据（dataRoot 下） | 多选规则 |
|---|---|---|---|
| 正弦输出电压与码幅刻度 | `dac_scale_analysis` | `DA9726/sin_scale/DAC1_JG18` 下 `CODE/COADE` 十六进制码值 MAT | 支持多选，当前目录的9个原始MAT可一起选择；至少两点有效才能拟合刻度 |
| 输出噪声 | `dac_noise_analysis` | `DA9726/03_Noise` 下本次 MAT | 支持多选，逐文件计算 |
| 通道隔离度 | `dac_isolation_analysis` | `DA9726/05_Isolation` 下同驱动条件的参考与受扰 MAT | 先单选驱动，再一次多选全部受扰；显式配对清单仍可用 |
| 隔离度多通道切分 | `split_dac_isolation_channels` | 文件名包含接口顺序的PICO MAT | 按A/B/C/D拆成单通道MAT，并生成配对模板 |

例如运行 `dac_noise_analysis` 后选择两份噪声MAT，程序就只计算这两份。入口已包含 `uigetfile`，输出目录也可以省略。

## 刻度与噪声参数

默认值在 `private/da9726Config.m`。要只改本次，使用第四参数，不必修改配置文件：

```matlab
% d = 本次数据目录；files = 本次MAT文件名列表；out = 结果根目录。
settings = struct('dataVariables',{{'A'}},'hardwareGain',1);
r = dac_noise_analysis(d, files, out, settings);
```

这里只演示噪声调用；刻度另选对应波形，再用 `dac_scale_analysis(d,files,out,settings)`。文件列表支持cell、string或单个文件名。前三个位置参数留空时，可在第四参数中填写 `dataFolder/inputFiles/outputFolder`。位置参数非空时，使用位置参数，不使用同名配置字段。

| 设置 | 当前默认与用途 |
|---|---|
| `dataVariables` | 空时要求MAT在A/B/C/D中只有一个波形变量；多个变量时必须明确选择，如 `{'A'}`；一项可共用，也可逐文件给一项 |
| 时基和单位 | MAT必须有Tinterval或fs，Tinterval优先；波形单位为V。缺时基不会从文件名补猜 |
| `hardwareGain` | 1。经过已确认40 dB电压放大且尚未补偿时填100；已经补偿过保持1 |
| `toneFrequencyHz` | DA9726刻度当前固定1001000 Hz，对应DAC1_JG18这批采集 |
| `codeNameFormat` | DA9726刻度当前为hex_unsigned，读取CODE/COADE后的16位十六进制码；允许后接JG18、CH1、采样率等信息 |
| `codeVppDefinition` | 当前为raw_unsigned_code，横轴直接使用0x0000～0xFFFF无符号码值；signed_code只用于追溯 |
| 刻度筛选 | R²≥0.98，码值范围512～58982.4；0xFFFF超过当前拟合上限，因此保留测量但不进入直线拟合 |
| 噪声 | Hann、0.2 Hz目标分辨率、50%重叠，1 Hz读数至少4段，频点相对误差≤25% |
| 噪声输出/比较 | ASD-only，75 µV/√Hz；配置中的积分频带/120 µVrms本次模式不启用 |
| 正式判定 | `formalEnabled=false`，需求、负载和参考面尚未完全确认 |

刻度先看 `dac_scale_measurements.csv` 的 `output_vpp_v`，再看 `dac_scale_summary.csv` 和拟合PNG。这是正弦峰峰电压，不是独立DC输出电压。噪声看 `dac_noise_summary.csv` 的 `asd_at_1hz_uV_per_sqrtHz`，单位已是µV/√Hz，同时查看实际分辨率、段数和coverage。

当前DAC1_JG18刻度文件名如 `COADE_E000_JG18_CH1_39_1MSPS_10usdiv.mat`。直接运行 `dac_scale_analysis`，进入 `sin_scale/DAC1_JG18` 并选择这批9个原始MAT即可。不要把文件名改成十进制；程序按十六进制读取，例如 `E000=57344`、`FFFF=65535`。MAT中的实际采样率仍从 `Tinterval` 读取；当前数据约为39.062499 MSPS。

## 隔离度：参考文件与受扰文件要成对

### 多通道PICO MAT先切分

`split_dac_isolation_channels` 用于同一次PICO采集中包含A/B/C/D多路波形的MAT。父目录名采用“驱动接口-名义频率”，例如 `JG18-1M`；源文件名按通道顺序列出接口，例如 `JG18-JG20-JG21-JG23-200K-2ms.mat`。程序将文件名中的接口依次对应实际存在的A/B/C/D。接口数与波形数不一致时直接报错，不猜测接线。

当前 `JG18-1M` 数据的已核对映射为：长文件A/B/C/D分别对应JG18/JG20/JG21/JG23，短文件D对应JG25。切分后每份MAT只保留一个名为A的波形，同时记录原文件、原变量、接口和SHA-256。`Tinterval` 等PICO时基字段原样保留；当前两份数据的采样率约为9.76562487 MHz。原始MAT不改写。

```matlab
d = ['F:/01_Laser/0_20260727_513test/CW_Data/513_CW_jianding/' ...
    'DA9726/03_Isolation/JG18-1M'];
files = {'JG18-JG20-JG21-JG23-200K-2ms.mat', ...
    'JG25-200K-2ms.mat'};

% 参考面和负载尚未确认时先留空，只生成不可直接分析的配对模板。
splitResult = split_dac_isolation_channels(d, files, [], struct());

% 条件已确认后可直接生成可运行清单。文字必须按真实接线填写。
settings = struct('referencePlane', '填写共同参考面、负载和探头条件');
splitResult = split_dac_isolation_channels(d, files, [], settings);
r = dac_isolation_analysis(splitResult.outputFolder, ...
    splitResult.pairManifestPath, [], struct('hardwareGain',1));
```

输出位于 `split/run_时间_channel_split`。`channel_manifest.csv` 是切分追溯清单；`pair_manifest_template.csv` 按父目录的JG接口建立“驱动→其余接口”配对。程序把文件夹中的1M作为名义值，在驱动路附近精确找峰，再用同一实测频率拟合所有受扰路。当前驱动路主峰约在1.00098 MHz附近，实际输出以每次计算为准。若驱动拟合R²低于0.98，或没有填写共同参考面和负载，`pairManifestPath` 保持为空，不能直接运行正式分析。

如文件名不能表达通道顺序，可通过 `options.channelMapping` 提供含 `source_file`、`source_variable`、`channel_label` 的table或struct；也可用 `drivenLabel` 和 `nominalFrequencyHz` 覆盖父目录解析值。

运行 `dac_isolation_analysis` 后：

1. 选择驱动输出的参考MAT。
2. 在第二个窗口一次多选同一驱动条件下的全部受扰MAT。

选完直接计算，不再弹参数输入框。程序从切分MAT的 `ChannelLabel` 或文件名前缀读取接口，自动选择唯一A/B/C/D变量，从驱动路寻找最强非DC正弦并精确拟合频率，所有受扰路使用同一频率。交互模式固定 `hardwareGain=1`，测量条件记录为“PicoScope输入端直接测量；无外部放大；输入阻抗和探头倍率未记录”。因此可以得到隔离度数值，但正式状态保持“暂不能判定”。任何一步取消都不写结果。

交互模式只接受每份包含一个A/B/C/D波形的单通道MAT。若仍是多通道PICO原文件，先运行 `split_dac_isolation_channels`。驱动文件不得在受扰列表中重复出现；驱动拟合R²低于0.98时停止计算。

函数签名为 `(dataFolder,pairManifest,outputFolder,configOverride)`。第二参数是配对清单，不能传普通MAT文件列表。支持struct数组、table或CSV清单路径；显式多行清单会处理其中每一对，不弹窗。

需要一次全选并自动识别驱动时，可使用：

```matlab
settings = struct('autoDetectDrive',true, ...
    'inputFiles',{{'JG18.mat','JG20.mat','JG21.mat','JG23.mat','JG25.mat'}});
r = dac_isolation_analysis(d, [], out, settings);
```

自动模式在各文件的共同主频处比较Vpp，最大者为驱动。最大和次大幅值默认至少相差10 dB，否则拒绝自动识别，改用默认的“先选驱动、再多选受扰”。

每行包含：

| 字段 | 填写内容 |
|---|---|
| `driven_file`、`victim_file` | 参考/受扰MAT的相对或绝对路径；相对路径基于dataFolder |
| `driven_variable`、`victim_variable` | 真实波形变量，如A/B |
| `driven_label`、`victim_label` | 实际物理接口 |
| `frequency_hz` | 已确认的共同驱动频率 |
| `reference_plane` | 共同参考面和负载；也可用第四参数referencePlane统一提供 |

示意配置：

```matlab
% d/out为本次目录；以下接口、频率、文件、参考面均需按测试记录填写。
pair = struct('driven_file','reference.mat','victim_file','victim.mat', ...
    'driven_label','驱动接口','victim_label','受扰接口', ...
    'driven_variable','A','victim_variable','A', ...
    'frequency_hz',1000,'reference_plane','已确认的共同参考面与负载');
r = dac_isolation_analysis(d, pair, out, struct('hardwareGain',1));
```

结果看 `dac_isolation_summary.csv` 的 `isolation_db`，并同时检查驱动/受扰采样率、驱动拟合R²、受扰拟合R²、Vpp和频率偏差。程序另写 `dac_isolation_matrix_db.csv`，按“驱动接口×受扰接口”整理同一批 dB 数值；`dac_isolation_summary.png/.fig` 现在是对应的矩阵热力图，单元格直接标出 dB，颜色范围只根据有限测量值计算，不再用40 dB参考线把坐标压成39–41 dB。40 dB仍只作为配置中的参考阈值，不参与热力图范围。受扰路信号接近噪声时R²可以很低，因此只作为质量信息；驱动路R²低于阈值时不得作正式判断。原数据出现过名义1 MHz而采样率250 kS/s的条件，不能据此给出正式1 MHz隔离结论。配对关系填写完整也不代表测量方法已经验证。

本目录提供刻度、噪声和隔离度分析，不提供DAC INL/DNL、独立DC电压或相位噪声分析。

## 查看结果

先查看 summary CSV 中的数值、状态和说明，再查看 PNG。运行参数记录在 `analysis_parameters.csv`、`run_config.mat` 或结果 MAT 中；输入文件见 `run_manifest.csv` / `source_manifest.csv`。

程序运行成功不代表器件指标合格。SFDR 定义、带宽混叠、隔离度拟合质量和频率检查、噪声参考面等仍需核对；文件选择功能的测试不能替代这些检查。

## 报告刻度配置

本器件的报告刻度由 `private` 配置中的 `reportCalibration` 字段加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。
