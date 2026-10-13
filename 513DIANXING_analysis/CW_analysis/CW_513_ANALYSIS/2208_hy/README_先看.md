# AD2208 分析脚本使用说明

## 2026-10-12：先选择板型，再使用刻度

鉴定件和电性加强件使用各自报告的刻度表。需要刻度的噪声入口在交互运行时询问板型，每次重新选择；显式传文件时填写 `boardType='jianding'`（鉴定件）或 `'jiaqiang'`（电性加强件）。

`calibrationState='current'` 优先使用该接口的改焊后记录；仅有一条记录时沿用该记录及其原状态。`'before'`、`'after'` 用于明确要求对应版本；该接口没有所选版本时会列出可用版本并结束。

长期刻度统一维护在 [`report_calibrations_20261004.csv`](../_shared/+converter/+calibration/report_calibrations_20261004.csv)。private 只保存分析参数。逐行数值、来源和自定义刻度示例见 [CALIBRATION.md](../CALIBRATION.md)。

运行时显示实际板型、接口、版本和斜率；打开 `结果汇总.xlsx` 查看简短刻度说明，完整记录在 `evidence` 的配置/结果 MAT 与刻度 CSV 中。单位为 **V/code**；噪声去均值后仅使用斜率，截距不参与噪声换算。历史结果保持原样。


## 参数怎么改（2026-10-02 配置整理）

长期默认值改本目录 `private` 的配置文件；只改一次测试时，使用入口已有的配置参数。实际顺序是：默认值 → 本次覆盖 → 派生值计算与校验。未填写的字段沿用默认值。数据目录、文件列表、输出目录的位置参数非空时，优先使用位置参数。

参数拼错会报错并提示相近字段。自定义说明放在 `metadata`，例如 `struct('metadata',struct('operator','实验员'))`。常规ADC可使用直接字段或 `struct('configOverride',settings)`，不要两种形式混放；`powerSetpoints`仍是刻度的独立输入。其他入口的特殊签名以本文说明为准。

运行开始时会显示主要参数。常规结果的 `evidence/run_config.mat` 保存最终配置，其中 `parameterSources` 说明字段来自默认值、本次覆盖还是派生计算；PICO联合噪声查看结果MAT的 `result.config`。9726直流输出电压保留原输出布局，在运行目录增加 `run_config.mat`，变量名为 `options`。精简XLSX不增加过程参数列。

完整入口和配置分支对照见 [配置使用说明](../CONFIGURATION.md)。旧运行配置中的已知停用字段兼容保留并提示不生效，不代表这些开关已经实现。

- `sfdr/bandwidth/power_scale/isolation/inl_dnl/input_noise`仍对应原单项分析；新增 `pico_noise` 集中保存PICO参数。
- ILA噪声保持100 MHz、单段、NFFT=131072、10～25 MHz；PICO保持FPGA增益128、Hann、目标频点间隔0.2 Hz、50%重叠，DA9726 JG18 按所选板型读取随代码发布的刻度表。
- 隔离度当前默认驱动为ADC5_JG22；带宽当前R²下限0.95。正式判定开关现已显式填写，未改变原来的判定行为。


更新：2026-09-20。

在 MATLAB 编辑器中打开对应脚本并点击 Run，也可以在命令窗口输入函数名。不带参数运行时，按弹窗选择原始文件。程序只处理选中的文件；在文件、接口或测量条件对话框中取消，均不生成结果。

换器件时先在命令窗口执行：

```matlab
restoredefaultpath;
clear functions;
cd('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/2208_hy');
dataRoot = 'F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA';
```

不同器件有同名函数，用 `which 函数名 -all` 检查调用路径。不要用 `genpath` 加载整个库。运行时需要本器件的 `private` 和相邻的 `_shared`；2208/9245 PICO 噪声还需要 `noise_chain_hy`。这些依赖由入口加载，不用单独运行。

## 输入文件与结果目录

- CSV 项目选择原始 CSV；PICO/DAC 项目选择原始 MAT。汇总 CSV、结果 MAT 和配对清单不是原始波形。
- 只传数据目录而不传文件列表时，在该目录打开选择框，不扫描整个目录。默认目录也只用作选择框的起始位置。
- 相对文件名以给定的数据目录为准；也支持绝对路径。传入非空文件列表或有效配对清单时直接运行，不弹选择框。
- 不改写原始数据。省略输出目录时，输入目录名为 `raw` 就写到它旁边的 `results`，否则写到该目录内的 `results`。 PICO 1 Hz 入口保留原规则：总是写入所选目录内部的 `results`，包括 `raw/results`。
- 每次创建新的 `run_日期_时间_项目` 子目录；同一秒再次运行会加序号。命令窗口打印完整路径，历史结果保留。
- 新结果目录外层只保留 `结果汇总.xlsx` 和 PNG 图。逐点 CSV、结果 MAT、可编辑 FIG、参数、哈希、日志和状态放在 `evidence` 子目录。本文提到的 CSV 均在该子目录；旧结果不自动搬动。
- 重复文件或会生成同名图谱的文件会报错，避免相互覆盖。通道、参考面、增益和负载以测量记录为准，文件名不能代替这些记录。

## 脚本与数据

以下 CSV 项目支持多选。一次选择同一接口、同一测试条件的一组文件；隔离度选择同一驱动条件下的参考和受扰记录，每通道一份。

| 分析项目 | 运行脚本 | 数据位置（dataRoot 下） | 先看哪个结果 |
|---|---|---|---|
| SFDR、SNR、SINAD、THD、ENOB | `adc_sfdr_analysis` | `AD2208/01_SFDR` | `ADC_SFDR_summary.csv` |
| 3 dB 带宽 | `adc_bandwidth_analysis` | `AD2208/02_FrequencyResponse` | `ADC_bandwidth_summary.csv` |
| 输入刻度、99%临界输入估计 | `adc_power_scale_analysis` | `AD2208/03_InputPowerScale` | `ADC_vpp_codepp_calibration.csv`、`ADC_critical_input_estimate.csv` |
| 通道隔离度 | `adc_isolation_analysis` | `AD2208/04_Isolation` | `ADC_isolation_summary.csv` |
| ADC INL/DNL | `adc_inl_dnl_analysis` | `AD2208/05_INL_DNL` | `ADC_inl_dnl_capture_metrics.csv`，再看 summary、曲线 |
| 直接 ILA 高频噪声 | `adc_ila_noise_analysis` | `AD2208/06_Noise/01_HighFrequency_ILA` | `AD2208_input_noise_summary.csv` |
| PICO 1 Hz 链路噪声 | `adc_pico_noise_1hz_analysis` | `AD2208/06_Noise/02_1Hz_PICO` | `input_equiv_noise_summary.csv` |

例如只做 SFDR，输入 `adc_sfdr_analysis`，在选择框进入本次采集目录并勾选 CSV。带宽选一组扫频；刻度选同频、不同输入幅度的一组记录；INL/DNL 选同一接口的正弦记录。不要把一组文件依次交给所有指标。

## 默认参数

常规 CSV 参数在 `private/ad2208Config.m` 的对应 `case` 中。下表列出脚本默认值，运行前应与仪器设置核对：

| 项目 | 当前关键设置 |
|---|---|
| CSV 采样时基、码型 | 100 MHz、16 bit signed、第4列 |
| SFDR | NFFT=131072；DC/基波跨度16、谐波跨度8、最高8次谐波 |
| 带宽 | 正弦拟合R²≥0.95；最低频连续3个有效点作参考；频差容差2% |
| 刻度 | 1 MHz，−10～+8 dBm；R²≥0.98，排除频率失配，保留现有未削顶点筛选及自动上限方法；已确认50 Ω条件才按50 Ω换算 |
| 隔离度 | 1 MHz，配置默认驱动 ADC5_JG22；比较值40 dB |
| INL/DNL | R²≥0.999，marginCode=0，不额外裁剪正弦两端；有效记录比例100%；默认各记录独立触发 |

刻度拟合为 `Vpp=a*CodePp+b`，同时估计99%满量程对应的临界输入。98%近轨筛选与99%目标是不同设置；外推结果仍需补扫，不能当作实测削顶点。输入设定值可由 `runOptions.powerSetpoints` 的 table 提供，至少含 `FileName` 及 `InputVoltageVpp` 或 `InputPowerDbm`；可以同时记录 `ReferenceImpedanceOhm`、`InputPowerSource`、`InputPowerDefinition`。

带宽当前还标注30 MHz及70 MHz以上阻带参考；100 MHz采样的Nyquist为50 MHz，较高输入频率需要结合混叠解释。

## 隔离度文件配对

运行 `adc_isolation_analysis` 后：

1. 选择同一次驱动条件下的 CSV，必须包括驱动通道自己的参考记录，以及至少一份受扰记录。
2. 程序按 CSV 采集表头确定记录通道；表头无法确认时让你选接口。
3. 在列表中选择接入信号源的驱动通道，再确认输入频率、共同参考面和连接条件。

只选受扰文件无法计算隔离度。每通道一次一份，避免把不同驱动条件混在一起。程序不再从文件名自动改写驱动通道。

带参数调用时，第三参数是结果根目录，第四参数按字段覆盖默认配置。未提供的配置字段继续使用默认值。表头不含通道时，按文件顺序填写 `inputChannels`。示意调用如下，`d/files/out` 替换为本次已确认的数据目录、文件列表和输出根：

```matlab
options = struct('drivenChannel','ADC2_JG17', ...
    'isolationFrequencyHz',1e6, ...
    'referencePlane','填写本次参考面、负载和连接条件');
r = adc_isolation_analysis(d, files, out, options);
```

## 带参数调用

下表是接口说明；日常点击 Run 不必填写全部参数。`files` 非空时不弹文件选择框；省略 `out` 使用上面的默认结果位置。

| 函数 | 参数顺序 | 本次可改参数 |
|---|---|---|
| `adc_sfdr_analysis` | `(d,files,out,runOptions)` | 第四参数覆盖本次设置，例如 inputRadix |
| `adc_bandwidth_analysis` | `(d,files,out,runOptions)` | 直接字段或 `configOverride` 子结构 |
| `adc_power_scale_analysis` | `(d,files,out,runOptions)` | 同上；另支持 `powerSetpoints` |
| `adc_isolation_analysis` | `(d,files,out,configOverride)` | 驱动通道、频率、参考面、inputChannels 等 |
| `adc_inl_dnl_analysis` | `(d,files,out,recordsAreSampleContiguous,runOptions)` | 第四参数仍为连续性布尔值；第五参数传本次设置 |

### CSV 是十六进制还是十进制

`adcCodeFormat='signed'` 表示补码解释，`inputRadix` 表示 CSV 文本用哪种进制，两者不同。
按 ILA 导出设置选择 `inputRadix='hex'` 或 `'decimal'`，不要根据数字外观猜。
默认 `auto` 优先读取 CSV 的进制声明；没有充分证据时，交互运行让你选择，显式运行报错要求补参数。

```matlab
options = struct('inputRadix','hex'); % 本次ILA确实导出了十六进制
r = adc_sfdr_analysis(d, files, [], options);
r = adc_power_scale_analysis(d, files, [], options);
r = adc_inl_dnl_analysis(d, files, [], false, options);
```

实际采用的进制、数据列、保留点数写入 `evidence/input_decoding.csv`。表头不能确认接口时，
还需在 options 中填写与文件逐一对应的 `inputChannels`。INL/DNL 只允许合并同一接口；不同接口必须分开运行。

### 指标怎样解读

- SFDR 保留 Hann 窗峰值频点法；同样的音调落在不同 FFT 栅格位置，结果可能略有变化。现在先排除 DC 再找基波，Nyquist 频点仍参与杂散搜索；基波与 DC 排除区重叠时明确报错。
- THD 改为 `10*log10(谐波功率/基波功率)`。例如谐波幅度为基波的 1%，THD 为 −40 dB。旧版输出的 +40 dB 是相反比值，不能直接混用。
- 带宽明细保留所有频点。达到或超过 Nyquist 的点默认保留并参与带宽，`NyquistOrAboveFlag=1` 仅标注混叠（100 MHz采样的Nyquist为50 MHz，更高输入频率需结合混叠解释）；如需恢复剔除可传 `struct('rejectNyquistOrAbove',true)`。拟合退化或拟合幅值超出码域的点不参与带宽。`InsufficientCyclesFlag=true` 表示记录少于两个周期，应补长记录核对；能算出交点也不代表正式满足。
- 隔离度 `IsolationDb` 是 ADC 码幅比，未自动补偿不同接口的模拟增益。`ThresholdMet` 只表示数值过阈值；`Pass` 还要求驱动质量、频率及参考条件通过，并显式允许正式判定。参考条件不全时看 `FormalConclusion=暂不能判定`，不能把 `Pass=false` 简单理解为器件不合格。
- INL/DNL 是公共有效码域的码密度结果，INL 去除一阶最佳拟合直线。未命中的码可能来自缺码，也可能来自采样相位不足；`IncompleteCodeCoverage` 要补充记录核查。全覆盖也只标 `Computed_MethodValidationRequired`，不自动宣称方法或器件已合格。

## ILA 高频噪声

运行 `adc_ila_noise_analysis`，在弹窗中选择本次 CSV。JG15、JG17、JG22 三份文件只在选中后处理。可多选不同接口；同一接口每次一份，因为当前核心用接口名保存图谱，多次采集请分别运行。

```matlab
d = fullfile(dataRoot,'AD2208','06_Noise','01_HighFrequency_ILA');
r = adc_ila_noise_analysis(d, {'JG15.csv'}, [], ...
    struct('boardType','jianding','inputRadix','decimal')); % 只处理这一份，不弹窗
```

函数签名为 `(dataFolder,selectedFiles,outputFolder,runOptions)`。第四参数可传本次配置；表头无法识别通道时传 `struct('inputChannels',{{'ADC1_JG15'}})`，与文件逐一对应。若与表头冲突会报错。缺刻度接口会在创建运行前报错。

`private/ad2208Config.m` 中的 `input_noise` 设置为：

```matlab
config.welchSegmentCount = 1;
config.welchOverlapRatio = 0;
config.welchNfft = 131072;
```

对131072个有效点、100 MHz的记录，使用全长Hann窗一次计算，不做分段平均；频率点间隔为 762.939453125 Hz，记录时长1.31072 ms。代码仍通过 `pwelch` 计算并保留原全记录周期图输出；在这组参数下两者应数值一致。单段模式下，记录长度不等于NFFT时报错，不自动补零、折叠或改变NFFT。该短记录不能测1 Hz噪声。

目标频带为10～25 MHz，比较值为300 nV/√Hz，判据不变。单段噪声估计没有分段平均的平滑效果，不能直接与旧平均结果混作同一处理条件。参考面、接地和尖峰判定仍须核对。

去均值后乘所选板型、接口的刻度斜率。两板对照见 [CALIBRATION.md](../CALIBRATION.md)；鉴定件 JG24 为 `3.788345e-5 V/code`，加强件 JG24 改焊后为 `3.802132e-5 V/code`、改焊前为 `1.932029e-5 V/code`。

主要结果为 `AD2208_input_noise_summary.csv`、`AD2208_full_record_ASD_summary.csv`、接口谱CSV、PNG/FIG、刻度溯源和参数文件。当前 ILA 核心保存器件名对应的 `*_input_noise_result.mat`，包含完整结果与配置。旧参数CSV中有部分固定文本，查看时需与实际 summary 和运行配置核对。

## PICO 1 Hz 噪声：选一份 MAT，再选接口

运行 `adc_pico_noise_1hz_analysis`，选择一份PICO MAT，再明确ADC输入接口。一次单选是为防止同接口命名的结果相互覆盖。接口可选 JG15、JG17、JG19、JG22、JG24 对应的完整 ADC 名称，刻度配置必须唯一匹配。

```matlab
d = fullfile(dataRoot,'AD2208','06_Noise','02_1Hz_PICO','ADC6_JG24','raw');
options = struct('interface','ADC6_JG24','fpgaGain',128,'boardType','jianding');
r = adc_pico_noise_1hz_analysis(d, ...
    'JG24_128_250ksps_20s_2Vdiv.mat', "", options);
```

函数签名是 `(d,selectedFiles,out,runOptions)`。显式文件必须填写 `runOptions.interface`，缺少接口会报错而不是弹窗。默认只自动识别唯一PICO波形变量，多通道需填写waveVariable；模拟增益1、去均值；采样率读MAT的Tinterval或fs；FPGA增益128；1 Hz读数；Hann-Welch目标0.2 Hz、50%重叠。这里保留PICO的分段设置，ILA的单段变更不影响PICO。

默认参数在 `private/ad2208Config.m` 的 `pico_noise` 分支。可覆盖 `boardType/calibrationState/fpgaGain/asdCheckHz/referencePlane/plotDpi/waveVariable` 和 `welch` 子字段。内置 ADC 与 DA9726 JG18 使用同一板型；自定义刻度需同时明确 ADC 和 DAC 来源，见公共刻度说明。

默认结果在所选目录内部 `results/run_时间_ad2208_pico_noise_1hz`；返回 `r.runFolder`。看 `input_equiv_noise_summary.csv` 的 `input_asd_at_check_n_v_per_sqrt_hz`（nV/√Hz，除1000为µV/√Hz），同时看formal_state和note。当前整条链未扣除PICO/DAC本底，不能据此声称ADC本征噪声合格。

## 查看结果

先查看 summary CSV 中的数值、状态和说明，再查看 PNG。运行参数记录在 `analysis_parameters.csv`、`run_config.mat` 或结果 MAT 中；输入文件见 `run_manifest.csv` / `source_manifest.csv`。

程序运行成功不代表器件指标合格。SFDR 定义、带宽混叠、隔离度拟合质量和频率检查、噪声参考面等仍需核对；文件选择功能的测试不能替代这些检查。

## 报告刻度配置

本器件的两板刻度统一保存在 [`report_calibrations_20261004.csv`](../_shared/+converter/+calibration/report_calibrations_20261004.csv)，在需要电压换算时选择。完整数值与版本见 [CALIBRATION.md](../CALIBRATION.md)。刻度入口继续用所选扫描数据拟合。DAC 电压噪声只使用实测电压及电压增益，SFDR、相对带宽、码比隔离度和 INL/DNL 保持原计算方式。

## PICO MAT里有多个波形通道时怎么办

这里的“ADC接口”与“PICO波形变量”是两件事：interface指定板上的输入接口；waveVariable指定MAT里的A、B、C或D。

- MAT只有一个A/B/C/D波形时，不需要填写waveVariable，程序会记录实际变量名。
- MAT有多个波形时，在第四参数runOptions中写明`'waveVariable','A'`（按实际采集选择A/B/C/D）。程序不会默认挑第一个。
- 如果明确指定A，但MAT只有B，程序会报错，不会悄悄换到B。核对采集记录后再修改参数。

例如，在已有参数结构options上增加：

```matlab
options = struct('boardType','jianding','interface','ADC6_JG24');
options.waveVariable = 'B';  % 仅在本次采集确实保存在B时这样写
r = adc_pico_noise_1hz_analysis(dataFolder, {'本次原始文件.mat'}, outputFolder, options);
```

options.interface仍须按本次真实板卡接口填写，其他增益、刻度和Welch参数不因选择B而改变。输出摘要中的wave_variable记录实际分析了哪个PICO变量。
0.2 Hz频点间隔对应每段约5秒；这只够一段。默认覆盖检查还要求至少4段，50%重叠时通常需要至少12.5秒总记录。摘要中的asd_coverage_adequate只表示频率和分段覆盖满足配置，不代表器件性能已通过验收。

## 按板型复跑噪声的最小示例

```matlab
options = struct('boardType','jianding','calibrationState','current');
% CSV 的实际进制及接口需与采集记录一致
options.inputRadix = 'decimal';
r = adc_ila_noise_analysis(dataFolder, selectedCsvFiles, outputFolder, options);

options = struct('boardType','jiaqiang','calibrationState','current', ...
    'interface','ADC6_JG24','fpgaGain',128);
r = adc_pico_noise_1hz_analysis(dataFolder, 'capture.mat', outputFolder, options);
```
