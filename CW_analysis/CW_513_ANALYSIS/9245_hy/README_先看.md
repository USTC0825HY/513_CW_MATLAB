# AD9245 分析脚本使用说明

更新：2026-09-09。

在 MATLAB 编辑器中打开对应脚本并点击 Run，也可以在命令窗口输入函数名。不带参数运行时，按弹窗选择原始文件。程序只处理选中的文件；在文件、接口或测量条件对话框中取消，均不生成结果。

换器件时先在命令窗口执行：

```matlab
restoredefaultpath;
clear functions;
cd('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/9245_hy');
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

以下 CSV 项目支持多选。一次选择同一接口、同一测试条件的一组文件；隔离度选择同一驱动条件下的参考和受扰记录，每通道一份。

| 分析项目 | 运行脚本 | 数据位置（dataRoot 下） | 先看哪个结果 |
|---|---|---|---|
| SFDR、SNR、SINAD、THD、ENOB | `adc_sfdr_analysis` | `AD9245/06_SFDR` | `ADC_SFDR_summary.csv` |
| 3 dB 带宽 | `adc_bandwidth_analysis` | `AD9245/02_FrequencyResponse` | `ADC_bandwidth_summary.csv` |
| 输入刻度、99%临界输入估计 | `adc_power_scale_analysis` | `AD9245/03_InputPowerScale` | `ADC_vpp_codepp_calibration.csv`、`ADC_critical_input_estimate.csv` |
| 通道隔离度 | `adc_isolation_analysis` | `AD9245/04_Isolation` | `ADC_isolation_summary.csv` |
| ADC INL/DNL | `adc_inl_dnl_analysis` | `AD9245/05_INL_DNL` | `ADC_inl_dnl_capture_metrics.csv`，再看 summary、曲线 |
| PICO 1 Hz 链路噪声 | `adc_input_noise_analysis` | `AD9245/01_noise` | `input_equiv_noise_summary.csv` |

例如只做 SFDR，输入 `adc_sfdr_analysis`，在选择框进入本次采集目录并勾选 CSV。带宽选一组扫频；刻度选同频、不同输入幅度的一组记录；INL/DNL 选同一接口的正弦记录。不要把一组文件依次交给所有指标。

## ILA采样率：旧数据25 MHz，后续数据20 MHz

AD9245旧ILA数据为25 MHz（40 ns），后续计划改为20 MHz（50 ns）。只有实际用20 MHz采集的新数据才按20 MHz分析，旧数据仍用25 MHz，不要在同一次运行中混用两种时基的文件。

当前MATLAB的 `9245_hy/private/ad9245Config.m` 仍设置 `ilaCaptureSampleRateHz=25e6`，SFDR、带宽、隔离度、功率刻度和INL/DNL的 `config.sampleRate` 均取这个值。`adcConversionClockHz=20e6` 表示ADC转换时钟，不能代替旧CSV的ILA时基。本次只修正文档，脚本默认值未改，也未核验后续FPGA时钟修改是否已完成。

分析20 MHz新数据前，需同步设置 `sampleRate=20e6`、`ilaCaptureSampleRateHz=20e6`，并将 `ilaCaptureClock` 和 `sampleRateSource` 写为实际采集时钟及其来源，不能继续记录旧的 `clk_25m_cp`。

带宽、功率刻度和隔离度支持第四参数 `runOptions`，可通过 `configOverride` 覆盖上述字段。SFDR和INL/DNL没有第四参数，需在运行前调整 `private/ad9245Config.m`。换回旧数据时，恢复25 MHz和对应来源说明。修改配置后执行 `clear functions`，并检查输出的 `run_config.mat`。

PICO噪声入口读取MAT中的时基，与这里的ILA采样率无关。

## 默认参数

常规 CSV 参数在 `private/ad9245Config.m` 的对应 `case` 中。下表列出脚本默认值，运行前应与仪器设置核对：

| 项目 | 当前关键设置 |
|---|---|
| CSV 采样时基、码型 | 当前默认及旧数据为ILA 25 MHz；实际改用20 MHz采集后的新数据用20 MHz。14 bit signed、自动数据列；ADC转换时钟单独配置为20 MHz |
| SFDR | NFFT=131072；DC/基波跨度16、谐波跨度8、最高8次谐波 |
| 带宽 | 正弦拟合R²≥0.99；最低频连续3个有效点作参考；频差容差2% |
| 刻度 | 1 kHz，−10～+6 dBm；已确认50 Ω条件才按50 Ω换算 |
| 隔离度 | 10 kHz，配置默认驱动 X3G；比较值40 dB |
| INL/DNL | R²≥0.99，两端1000码余量，有效记录比例100%；默认各记录独立触发 |

刻度拟合为 `Vpp=a*CodePp+b`，同时估计99%满量程对应的临界输入。98%近轨筛选与99%目标是不同设置；外推结果仍需补扫，不能当作实测削顶点。输入设定值可由 `runOptions.powerSetpoints` 的 table 提供，至少含 `FileName` 及 `InputVoltageVpp` 或 `InputPowerDbm`；可以同时记录 `ReferenceImpedanceOhm`、`InputPowerSource`、`InputPowerDefinition`。


## 隔离度文件配对

运行 `adc_isolation_analysis` 后：

1. 选择同一次驱动条件下的 CSV，必须包括驱动通道自己的参考记录，以及至少一份受扰记录。
2. 程序按 CSV 采集表头确定记录通道；表头无法确认时让你选接口。
3. 在列表中选择接入信号源的驱动通道，再确认输入频率、共同参考面和连接条件。

只选受扰文件无法计算隔离度。每通道一次一份，避免把不同驱动条件混在一起。程序不再从文件名自动改写驱动通道。

带参数调用时，第三参数是结果根目录，第四参数按字段覆盖默认配置。`runOptions` 也支持 `configOverride` 子结构。表头不含通道时，按文件顺序填写 `inputChannels`。示意调用如下，`d/files/out` 替换为本次已确认的数据目录、文件列表和输出根：

```matlab
options = struct('drivenChannel','X3G', ...
    'isolationFrequencyHz',10e3, ...
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
| `adc_isolation_analysis` | `(d,files,out,runOptions)` | 驱动通道、频率、参考面、inputChannels 等 |
| `adc_inl_dnl_analysis` | `(d,files,out)` | 无第四参数；连续性与质量门槛在 private 中修改 |

## PICO 1 Hz 噪声

直接运行 `adc_input_noise_analysis`，选择本次原始MAT，再逐份选X1G、X2G、X3G或X4G。可以多选，但每接口一次最多一份；相同接口的多次记录请分别运行，避免覆盖接口命名的谱文件。程序不根据G128文件名自动选取数据，也不使用固定的四文件列表。

函数签名为 `(dataFolder,outputFolder,runOptions)`，第二参数是输出目录。非交互调用通过第三参数明确文件和接口：

```matlab
d = fullfile(dataRoot,'AD9245','01_noise');
entry = struct('device','AD9245','interface','X3G', ...
    'matFile',fullfile(d,'X3G','X3G_100KSPS_CH1_G128.mat'));
options = struct('entries',entry,'fpgaGain',128);
r = adc_input_noise_analysis(d, [], options);
```

也可以使用 `options.selectedFiles` 和对应的 `options.interfaces`，二者一一对应。仅给目录、未提供entries/files时会弹文件选择框。错误接口、重复接口、缺失文件或ADC刻度会报错；显式输入错误不会转入弹窗。

默认PICO A、模拟增益1、去均值；采样率从MAT读取；FPGA增益128；1 Hz读数；Hann、0.2 Hz目标分辨率、50%重叠。参数在本噪声入口中；通过 `runOptions.fpgaGain`、`calibrationWorkbook`、`referencePlane`、`asdCheckHz`、`plotDpi` 等覆盖；`welch` 可只给需要改的子字段。ADC刻度默认使用随代码发布的20260903报告新刻度：X1G=6.705657e-5、X2G=6.643794e-5、X3G=6.718326e-5、X4G=6.695195e-5 V/CodePp。无需另传工作簿；显式提供 `calibrationWorkbook` 时才使用指定工作簿，以复现旧结果。报告噪声章节引用的旧系数不再作为默认值。

DA9726 JG18固定系数为1.014514e-4 V/CodePp，默认不读DAC刻度CSV。2208入口使用不同的固定系数，两者不要混用。当前总链路换算仍不扣PICO/DAC本底。

默认结果按前述raw同级/其它目录内部results规则，子目录名为 `run_时间_ad9245_input_equiv_noise_1hz`，返回 `r.runFolder`。先看 `input_equiv_noise_summary.csv`，再看每接口PSD/ASD、参数和source_manifest。部分记录已有完整性问题，必须检查每行状态和note；生成结果不能证明ADC本征噪声合格。

## 查看结果

先查看 summary CSV 中的数值、状态和说明，再查看 PNG。运行参数记录在 `analysis_parameters.csv`、`run_config.mat` 或结果 MAT 中；输入文件见 `run_manifest.csv` / `source_manifest.csv`。

程序运行成功不代表器件指标合格。SFDR 定义、带宽混叠、隔离度拟合质量和频率检查、噪声参考面等仍需核对；文件选择功能的测试不能替代这些检查。

## 报告刻度配置

本器件的报告刻度由 `private` 配置中的 `reportCalibration` 字段加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。
