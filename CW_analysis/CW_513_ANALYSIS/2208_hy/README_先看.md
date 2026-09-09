# AD2208 分析脚本使用说明

更新：2026-09-09。

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
| 带宽 | 正弦拟合R²≥0.99；最低频连续3个有效点作参考；频差容差2% |
| 刻度 | 1 MHz，−10～+8 dBm；R²≥0.98，排除频率失配，保留原连续未削顶区筛选；已确认50 Ω条件才按50 Ω换算 |
| 隔离度 | 1 MHz，配置默认驱动 ADC2_JG17；比较值40 dB |
| INL/DNL | R²≥0.999，两端1000码余量，有效记录比例100%；默认各记录独立触发 |

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
| `adc_sfdr_analysis` | `(d,files,out)` | 无第四参数；修改 private 中 sfdr 设置 |
| `adc_bandwidth_analysis` | `(d,files,out,runOptions)` | 直接字段或 `configOverride` 子结构 |
| `adc_power_scale_analysis` | `(d,files,out,runOptions)` | 同上；另支持 `powerSetpoints` |
| `adc_isolation_analysis` | `(d,files,out,configOverride)` | 驱动通道、频率、参考面、inputChannels 等 |
| `adc_inl_dnl_analysis` | `(d,files,out,recordsAreSampleContiguous)` | 第四参数仅为跨文件连续性布尔值 |

## ILA 高频噪声

运行 `adc_ila_noise_analysis`，在弹窗中选择本次 CSV。JG15、JG17、JG22 三份文件只在选中后处理。可多选不同接口；同一接口每次一份，因为当前核心用接口名保存图谱，多次采集请分别运行。

```matlab
d = fullfile(dataRoot,'AD2208','06_Noise','01_HighFrequency_ILA');
r = adc_ila_noise_analysis(d, {'JG15.csv'}); % 只处理这一份，不弹窗
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

刻度来自随代码发布的 `converter.calibration.reportCalibration('AD2208')`，由 `private/ad2208Config.m` 的 `reportCalibration` 字段加载。采用20260903报告“AD2208 刻度”表中的新结果，不使用噪声章节引用的旧系数。去均值后仅用斜率：

| 接口 | 斜率 V/CodePp | 截距 Vpp |
|---|---:|---:|
| ADC1_JG15 | 2.347136e-5 | 3.274615e-4 |
| ADC2_JG17 | 4.438060e-5 | -4.978057e-5 |
| ADC3_JG19 | 2.376230e-5 | 7.470679e-4 |
| ADC5_JG22 | 2.378017e-5 | 3.932618e-4 |
| ADC6_JG24 | 1.936920e-5 | 1.126594e-3 |

主要结果为 `AD2208_input_noise_summary.csv`、`AD2208_full_record_ASD_summary.csv`、接口谱CSV、PNG/FIG、刻度溯源和参数文件。当前 ILA 核心没有单独结果MAT；保留返回变量和整个运行目录。旧参数CSV中有部分固定文本，查看时需与实际 summary 和运行配置核对。

## PICO 1 Hz 噪声：选一份 MAT，再选接口

运行 `adc_pico_noise_1hz_analysis`，选择一份PICO MAT，再明确ADC输入接口。一次单选是为防止同接口命名的结果相互覆盖。接口可选 JG15、JG17、JG19、JG22、JG24 对应的完整 ADC 名称，刻度配置必须唯一匹配。

```matlab
d = fullfile(dataRoot,'AD2208','06_Noise','02_1Hz_PICO','ADC6_JG24','raw');
options = struct('interface','ADC6_JG24','fpgaGain',128);
r = adc_pico_noise_1hz_analysis(d, ...
    'JG24_128_250ksps_20s_2Vdiv.mat', [], options);
```

函数签名是 `(d,selectedFiles,out,runOptions)`。显式文件必须填写 `runOptions.interface`，缺少接口会报错而不是弹窗。默认PICO变量A、模拟增益1、去均值；采样率读MAT的Tinterval或fs；FPGA增益128；1 Hz读数；Hann-Welch目标0.2 Hz、50%重叠。这里保留PICO的分段设置，ILA的单段变更不影响PICO。

参数在该入口的 `localConfig`；本次可覆盖 `fpgaGain/asdCheckHz/referencePlane/plotDpi/calibrationWorkbook` 和 `welch` 子字段。ADC刻度默认读取上述代码配置，不需要另传工作簿；仅在显式提供 `calibrationWorkbook` 时读取指定旧工作簿，用于复现旧结果。DA9726 JG18斜率固定为 1.01451391294771e-4 V/CodePp，不寻找、不读取DAC刻度CSV；`dacSummaryPath` 已停用。

默认结果在所选目录内部 `results/run_时间_ad2208_pico_noise_1hz`；返回 `r.runFolder`。看 `input_equiv_noise_summary.csv` 的 `input_asd_at_check_n_v_per_sqrt_hz`（nV/√Hz，除1000为µV/√Hz），同时看formal_state和note。当前整条链未扣除PICO/DAC本底，不能据此声称ADC本征噪声合格。

## 查看结果

先查看 summary CSV 中的数值、状态和说明，再查看 PNG。运行参数记录在 `analysis_parameters.csv`、`run_config.mat` 或结果 MAT 中；输入文件见 `run_manifest.csv` / `source_manifest.csv`。

程序运行成功不代表器件指标合格。SFDR 定义、带宽混叠、隔离度拟合质量和频率检查、噪声参考面等仍需核对；文件选择功能的测试不能替代这些检查。

## 报告刻度配置

本器件的报告刻度由 `private` 配置中的 `reportCalibration` 字段加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。
