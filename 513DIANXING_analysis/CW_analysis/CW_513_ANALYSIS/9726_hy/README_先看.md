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
| 隔离度多通道切分 | `split_dac_isolation_channels` | 文件名包含接口顺序的PICO MAT | 按A/B/C/D拆成单通道MAT，并记录来源映射 |

例如运行 `dac_noise_analysis` 后选择两份噪声MAT，程序就只计算这两份。入口已包含 `uigetfile`，输出目录也可以省略。

### 噪声和刻度是两条独立流程

`dac_noise_analysis` 和 `dac_scale_analysis` 共用的只是文件选择、MAT 时基读取和结果目录管理，不会互相调用。噪声文件名如 `JG18.mat` 没有 DAC 码值，不能拿来做刻度拟合；刻度入口必须选择文件名中含 `CODE` 或 `COADE` 十六进制码值的正弦采集文件。刻度数据不在噪声目录中，不能用同一批 `JG18.mat` 等文件代替。

本机早上采集的噪声数据可直接指定到下面的目录，并只测试一份文件：

```matlab
d = 'G:/513_CW_test/CW_Data/513_CW_DATA/DA9726/03_Noise/nosie_20260901';
r = dac_noise_analysis(d, {'JG18.mat'}, fullfile(d, 'results'));
```

结果会写入 `G:/513_CW_test/CW_Data/513_CW_DATA/DA9726/03_Noise/nosie_20260901/results/run_日期_时间_noise`，原始 `JG18.mat` 不变。若只输入 `dac_noise_analysis`，程序会优先把这个本机目录作为选择框起始目录；换电脑时建议显式传入 `d`，或设置环境变量 `CW513_DATA_ROOT` 为包含 `DA9726` 的数据根目录。

刻度应另选实际的码值文件，例如：

```matlab
scaleDir = 'G:/513_CW_test/CW_Data/513_CW_DATA/DA9726/sin_scale/DAC1_JG18';
scaleFiles = {'CODE_1000_JG18_CH1_39_1MSPS_10usdiv.mat', ...
    'CODE_3000_JG18_CH1_39_1MSPS_10usdiv.mat'};
r = dac_scale_analysis(scaleDir, scaleFiles, ...
    fullfile(scaleDir, 'results'));
```

上面只列两份用于验证入口；正式刻度拟合应把同一批9个码值文件全部传入。
如果只有一个文件需要检查输入格式，第一个参数也可以直接写 MAT 的完整路径，第二个参数留空；刻度拟合仍至少需要两份有效码值。

文件名没有 `CODE/COADE` 码值时，刻度入口会报“文件名必须包含……码值”，这是输入类型不对，不是噪声脚本缺少刻度依赖。

如果噪声入口报 `converter:io:MatReadFailed`，先检查该 MAT 是否仍在写入或复制不完整。程序会给出文件大小和原始 MATLAB 错误；重新从 PicoScope 导出或完整复制后再运行。文件头能被识别不等于波形数组已经完整，不能用改扩展名或重新运行脚本修复缺失样本。

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
| `hardwareGain` | 噪声默认100（本批40 dB电压放大）；刻度和隔离度默认1。没有放大或已经补偿过的噪声，第四参数设置为1，避免重复补偿 |
| `toneFrequencyHz` | DA9726刻度当前固定1001000 Hz，对应DAC1_JG18这批采集 |
| `codeNameFormat` | DA9726刻度当前为hex_unsigned，读取CODE/COADE后的16位十六进制码；允许后接JG18、CH1、采样率等信息 |
| `codeVppDefinition` | 当前为raw_unsigned_code，横轴直接使用0x0000～0xFFFF无符号码值；signed_code只用于追溯 |
| 刻度筛选 | R²≥0.98，码值范围512～58982.4；0xFFFF超过当前拟合上限，因此保留测量但不进入直线拟合 |
| 噪声 | Hann、0.2 Hz目标分辨率、50%重叠，1 Hz读数至少4段，频点相对误差≤25% |
| 噪声输出/比较 | ASD参考75 µV/√Hz；同时计算1～100 kHz积分噪声，参考120 µVrms；正式判断仍关闭 |
| 正式判定 | `formalEnabled=false`，需求、负载和参考面尚未完全确认 |

噪声运行时控制台中的“配置采样率”只是兼容字段（默认 250 kHz）；实际计算采样率逐份从 MAT 的 `Tinterval`/`fs` 读取。以本次 `JG18.mat` 为例，结果摘要中的实际值约为 1.97784816 MHz，不能用控制台的兼容字段代替。

刻度先看 `dac_scale_measurements.csv` 的 `output_vpp_v`，再看 `dac_scale_summary.csv` 和拟合PNG。这是正弦峰峰电压，不是独立DC输出电压。噪声看 `dac_noise_summary.csv` 的 `asd_at_1hz_uV_per_sqrtHz`，单位已是µV/√Hz，同时查看实际分辨率、段数和coverage。

当前DAC1_JG18刻度文件名如 `COADE_E000_JG18_CH1_39_1MSPS_10usdiv.mat`。直接运行 `dac_scale_analysis`，进入 `sin_scale/DAC1_JG18` 并选择这批9个原始MAT即可。不要把文件名改成十进制；程序按十六进制读取，例如 `E000=57344`、`FFFF=65535`。MAT中的实际采样率仍从 `Tinterval` 读取；当前数据约为39.062499 MSPS。

## 隔离度：参考文件与受扰文件要成对

### 多通道PICO MAT先切分

`split_dac_isolation_channels` 只负责把PICO MAT中的A/B/C/D波形分别保存为单通道MAT。可以只选一份文件，也可以选择多份；不需要驱动通道、频率、参考面或特定目录名，不拟合信号，也不生成隔离度配对模板。

文件名中的JG接口按顺序对应实际存在的A/B/C/D。例如 `JG18-JG20-JG21-JG23-200K-2ms.mat` 切成4路，只有D变量的 `JG25-200K-2ms.mat` 切成1路。接口数与波形数不符时需通过第四参数的 `channelMapping` 指定映射（source_file、source_variable、channel_label）。

文件名幅值是百分比（如 `...-1MHz-10%.mat`）的四通道合测刻度数据，可加 `options.codeFromPercent` 让切分输出直接带上刻度入口需要的码值标记：换算规则为 `raw_code = round(百分比/100 × fullScaleCode)`，输出名注入 `CODE_<HEX>`，并在 `channel_manifest.csv` 记录百分比、规则、十六进制和码值。不传该选项时行为与旧版完全一致：

```matlab
r = split_dac_isolation_channels(d, files, [], ...
    struct('codeFromPercent', struct('fullScaleCode', 65535)));
```

```matlab
% 直接弹窗选择要切分的MAT，不必选入驱动参考。
split_dac_isolation_channels

% 只切分这份四通道文件：
d = 'G:/513_CW_test/CW_Data/513_CW_jianding/DA9726/03_Isolation/JG25-1M';
r = split_dac_isolation_channels(d, ...
    {'JG18-JG20-JG21-JG23-200K-2ms.mat'});
```

输出在所选目录的 `split/run_时间_channel_split`，包括单通道MAT、`channel_manifest.csv` 和 `channel_split_result.mat`。每份派生MAT的波形名统一为A，原始数值、时基、源变量和哈希可追溯；原始文件不修改。隔离度计算另行运行 `dac_isolation_analysis`，在该入口选择驱动参考和受扰数据。

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

先打开结果目录的 `结果汇总.xlsx` 查看数值、状态、参数和来源，再查看同目录PNG。完整CSV、MAT、FIG与追溯清单在 `evidence` 子目录；不再需要逐一寻找散落的CSV。已有历史结果目录不移动。

程序运行成功不代表器件指标合格。SFDR 定义、带宽混叠、隔离度拟合质量和频率检查、噪声参考面等仍需核对；文件选择功能的测试不能替代这些检查。

## 报告刻度配置

本器件的报告刻度由 `private` 配置中的 `reportCalibration` 字段加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。

### 噪声参数与通道检查（2026-09-20）

噪声计算先把MAT电压除以hardwareGain，再计算PSD；因此100倍增益只补偿一次：ASD和积分RMS除100，PSD除10000。MAT存在多个A/B/C/D波形时，必须在第四参数dataVariables中选定实际通道；显式指定A但文件只有B会报错，不会自动换通道。未指定通道时只接受唯一波形。遇到NaN/Inf会停止该记录，避免删除样点后把时基压短。

积分频带必须被实际频谱完整覆盖，而且频带内至少有两个频点；未覆盖时保留可计算的部分频带诊断值，但状态为暂不能判定，不能当成完整频带的RMS。窄到只有一个频点时返回NaN，不返回误导性的零。

刻度的横轴是本批文件名中的原始无符号十六进制幅度码（例如E000=57344），不能理解成实测DAC波形峰峰码。为兼容旧程序，CSV仍沿用code_vpp和slope_v_per_code_vpp字段名；请同时查看code_axis_definition=raw_unsigned_code。图已明确标注原始幅度码。至少两个不同码幅且各自正弦拟合合格，才给出刻度斜率；只有重复同一码值时状态为未测试。

## 2026-09-22 JG18噪声实跑与路径检查

指定文件 jg18_2MSPS_20S_CH1_G_100.mat 已用正式入口处理成功，未复现计算异常。实际A通道39556968点，Tinterval对应1977848.15998275 Hz、20.000002427秒。Length/RequestedLength为39556964，ExtraSamples=0，数组多4点，来源未明确；本次保留实际数组且没有删点。

按显式hardwareGain=100，Hann/0.2 Hz/50%重叠共7段：实际频点0.999999979767279 Hz的ASD为2.18227522136936 µV/√Hz，1～100 kHz积分为34.5675720224396 µVrms。负载和参考条件尚未闭环，正式状态暂不能判定。

入口已改为明确传入数据目录时不再查询旧默认盘符；公共噪声流程增加读取、Welch、完整频谱导出和结果整理进度。只改路径查找和提示，不改公式。完整频谱约494万行、CSV约385 MB，导出需要等待。

```matlab
cd('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/9726_hy');
d = 'I:/513_CW_test/CW_Data/513_CW_DATA_jianding/DA9726/20260922/9726 NOISE';
r = dac_noise_analysis(d, {'jg18_2MSPS_20S_CH1_G_100.mat'}, ...
    fullfile(d,'results'), struct('dataVariables',{{'A'}},'hardwareGain',100));
```

真实结果：该数据目录下 results/run_20260922_175311_noise/结果汇总.xlsx。诊断记录：F:/01_Laser/.codex_work/20260922-9726-noise。原始MAT的SHA-256为0AEFB4BE0961B940129D0A390005A29EF81DEB75051C88EDF4376810CB0F0E9B，运行前后保持一致。

## 四通道合测百分比命名刻度数据：先切分、再逐通道刻度（2026-09-22）

`9726-Retest/scale` 这批数据是4个DAC通道统一码值配置同时采集：每个MAT含A/B/C/D四路波形，文件名幅值为百分比（10%～99%，1 MHz）。scale 入口一次只拟合一条直线，且要求文件名含 `CODE/COADE` 十六进制码值，因此必须先切分成单通道、再按通道分别运行刻度，不能把4路混进一次拟合。

标准链路（以20260922鉴定复测数据为例）：

```matlab
d = 'F:/01_Laser/0_20260727_513test/513_test_data_0922/jianding/9726-Retest/scale';
% 1) 切分：百分比按满量程换算为码值（raw_code = round(pct/100*65535)）
r = split_dac_isolation_channels(d, [], [], ...
    struct('codeFromPercent', struct('fullScaleCode', 65535)));
% 2) 逐通道刻度：从 r.channelManifestPath 或 channel_manifest.csv 按接口挑文件，
%    每通道10档单独拟合；toneFrequencyHz 按实际输出频率覆盖（本批为1 MHz）。
scaleDir = r.outputFolder;
ch1 = dir(fullfile(scaleDir, 'JG20__CODE_*.mat'));
files = {ch1.name};
r1 = dac_scale_analysis(scaleDir, files, ...
    fullfile(d, 'results', 'CH1_JG20'), struct('toneFrequencyHz', 1000000));
```

通道与接口按文件名顺序对应（A=CH1/JG20、B=CH2/JG21、C=CH3/JG23、D=CH4/JG25），映射关系仍须与实际接线记录核对。切分manifest的 `raw_code` 列即刻度横轴：10%→6554(0x199A)、50%→32768(0x8000)、99%→64880(0xFD70)。

默认拟合上限 `maximumCodeVpp=0.9×2^16` 会把99%档（0xFD70）保留测量但不纳入直线拟合；确需纳入时在第四参数显式覆盖 `maximumCodeVpp` 并在测试记录中说明。某档4路波形均无1 MHz正弦（逐点拟合R²接近0）时，该档会被质量门槛自动排除出拟合，保留在measurements并注明原因；这类采集应核对DDS配置后重测，不能用拟合结果反推。
