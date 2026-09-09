# DA766 分析脚本使用说明

更新：2026-09-09。

在 MATLAB 编辑器中打开对应脚本并点击 Run，也可以在命令窗口输入函数名。不带参数运行时，按弹窗选择原始文件。程序只处理选中的文件；在文件、接口或测量条件对话框中取消，均不生成结果。

换器件时先在命令窗口执行：

```matlab
restoredefaultpath;
clear functions;
cd('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/766_hy');
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
| 正弦输出电压与码幅刻度 | `dac_scale_analysis` | `DA766/06_scale` 下同接口不同码值的 MAT | 支持多选，至少两点有效才能拟合刻度 |
| 当前06_scale的十六进制刻度 | `dac_scale_hex_analysis` | `DA766/06_scale` 下同接口CODE/COADE MAT | 支持多选，只取你选中的文件 |
| 输出噪声 | `dac_noise_analysis` | `DA766/03_DCNoise` 下本次 MAT | 支持多选，逐文件计算 |
| 通道隔离度 | `dac_isolation_analysis` | `DA766/05_Isolation` 下同驱动条件的参考与受扰 MAT | 交互一次一对；显式配对清单可多行 |

例如运行 `dac_noise_analysis` 后选择两份噪声MAT，程序就只计算这两份。入口已包含 `uigetfile`，输出目录也可以省略。

## 刻度与噪声参数

默认值在 `private/da766Config.m`。要只改本次，使用第四参数，不必修改配置文件：

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
| `toneFrequencyHz` | 通用刻度1000 Hz，按本次已确认正弦频率修改 |
| `codeNameFormat` | 通用刻度按signed_decimal，如code_30000；已确认16位十六进制时设置hex_unsigned，支持CODE/COADE |
| 刻度筛选 | R²≥0.98，CodePp范围512～58982.4；CodePp=2×abs(signedCode) |
| 噪声 | Hann、0.2 Hz目标分辨率、50%重叠，1 Hz读数至少4段，频点相对误差≤25% |
| 噪声输出/比较 | ASD参考12 µV/√Hz；积分1～100 kHz、参考1000 µVrms，仍需频带覆盖 |
| 正式判定 | `formalEnabled=false`，需求、负载和参考面尚未完全确认 |

刻度先看 `dac_scale_measurements.csv` 的 `output_vpp_v`，再看 `dac_scale_summary.csv` 和拟合PNG。这是正弦峰峰电压，不是独立DC输出电压。噪声看 `dac_noise_summary.csv` 的 `asd_at_1hz_uV_per_sqrtHz`，单位已是µV/√Hz，同时查看实际分辨率、段数和coverage。

## 当前十六进制刻度专用入口

运行 `dac_scale_hex_analysis`，在选择框进入 `06_scale/X7`、X9、X12G、X11-5等本次接口目录，勾选要处理的CODE/COADE MAT。不会自动纳入目录中其它记录；不适配的历史_CH2文件应留在原处、不要选中。

函数签名为 `(dataFolder,selectedFiles,outputFolder)`，没有第四参数。省略数据目录可直接选择MAT；省略输出使用默认results规则。

该专用入口保留1525 Hz、16bit补码、CodePp=2×abs(signedCode)、增益1、R²≥0.98、CodePp范围512～65536（纳入0x7FFF）。首个所选MAT提供配置中的采样率记录，内核逐文件读取实际时基。其它频率、增益或通道条件应使用通用刻度入口并明确参数。

## 隔离度：参考文件与受扰文件要成对

运行 `dac_isolation_analysis` 后：

1. 选择驱动输出的参考MAT。
2. 选择同一驱动条件下受扰输出的MAT。
3. 填写驱动接口、受扰接口、各自PICO波形变量、已确认频率（Hz）、共同参考面和负载、共同线性电压增益。

两个选择框均为单选，分别指定参考和受扰记录。两份记录的参考面与采集设置应可比较；两路增益不同且未补偿时，不能直接套用一个共同增益。任何一步取消都不写结果。

函数签名为 `(dataFolder,pairManifest,outputFolder,configOverride)`。第二参数是配对清单，不能传普通MAT文件列表。支持struct数组、table或CSV清单路径；显式多行清单会处理其中每一对，不弹窗。

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

结果看 `dac_isolation_summary.csv` 的 `isolation_db`，比较值仍40 dB。此前文件名20 kHz与拟合约19.836 kHz存在差异，应按已确认频率配置。同频拟合质量和频率检查仍需复核，配对关系填写完整并不代表测量方法已经验证。

本目录提供刻度、噪声和隔离度分析，不提供DAC INL/DNL、独立DC电压或相位噪声分析。

## 查看结果

先查看 summary CSV 中的数值、状态和说明，再查看 PNG。运行参数记录在 `analysis_parameters.csv`、`run_config.mat` 或结果 MAT 中；输入文件见 `run_manifest.csv` / `source_manifest.csv`。

程序运行成功不代表器件指标合格。SFDR 定义、带宽混叠、隔离度拟合质量和频率检查、噪声参考面等仍需核对；文件选择功能的测试不能替代这些检查。

## 报告刻度配置

本器件的报告刻度由 `private` 配置中的 `reportCalibration` 字段加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。
