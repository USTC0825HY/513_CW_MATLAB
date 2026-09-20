# AD9245 分析脚本使用说明

更新：2026-09-20。

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
- 新结果目录外层是 `结果汇总.xlsx` 和 PNG；逐点 CSV、MAT、可编辑 FIG、参数、来源哈希、日志及状态在 `evidence` 子目录。本文 CSV 文件名指该子目录内的文件。已有历史结果保持原布局。
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

## ILA采样率：当前20 MHz；旧25 MHz数据要显式修改

当前磁盘配置的ILA采样率为20 MHz，SFDR仍每5点保留1点，因此实际分析采样率是4 MHz，频谱覆盖到2 MHz。结果标签会明确写出源20 MHz、步长5、分析4 MHz。这个设置保留了用户现有参数。旧25 MHz数据需要显式改为源25 MHz、步长5、分析5 MHz；其频谱覆盖到2.5 MHz。不要将SFDR抽样规则套到其他指标。

`private/ad9245Config.m` 当前为 `ilaCaptureSampleRateHz=20e6`、`sfdrSampleStride=5`、`sfdrAnalysisSampleRateHz=4e6`。输出同时记录源/分析样点数、采样率、步长和用途；ADC转换时钟字段单独记录20 MHz，不是CSV时基证据。

分析20 MHz同步新数据时，必须同时设置 `sampleRate=20e6`、`ilaCaptureSampleRateHz=20e6`、`sfdrSampleStride=1`、`sfdrAnalysisSampleRateHz=20e6`，并更新 `sfdrSamplingMode`、`sfdrResultUse`、`ilaCaptureClock` 和 `sampleRateSource`。程序会拒绝“源采样率÷步长”与分析采样率不一致的配置。

SFDR、带宽、功率刻度、隔离度和INL/DNL都支持第四参数 `runOptions`，可通过 `configOverride` 覆盖本次字段。修改配置后执行 `clear functions`，并检查 `evidence/run_config.mat`。

PICO噪声入口读取MAT中的时基，与这里的ILA采样率无关。

## 默认参数

常规 CSV 参数在 `private/ad9245Config.m` 的对应 `case` 中。下表列出脚本默认值，运行前应与仪器设置核对：

| 项目 | 当前关键设置 |
|---|---|
| CSV 采样时基、码型 | 当前默认20 MHz；旧25 MHz采集必须覆盖为25 MHz。14 bit signed、自动数据列；ADC转换时钟单独记录 |
| SFDR | 当前20 MHz ILA每5点保留1点，按4 MHz分析；周期Hann窗；NFFT上限131072；DC/基波跨度16、谐波跨度8、最高8次谐波；仅为抽样估算 |
| 带宽 | 正弦拟合R²≥0.99；最低频连续3个有效点作参考；频差容差2% |
| 刻度 | 1 kHz；当前有效Vpp拟合范围0.1～2.1 Vpp；保留旧−10～+6 dBm配置但Vpp范围优先。已确认50 Ω条件才按50 Ω换算 |
| 隔离度 | 10 kHz，配置默认驱动 X3G；比较值40 dB |
| INL/DNL | R²≥0.99，marginCode=0，不额外裁剪正弦两端；有效记录比例100%；默认各记录独立触发 |

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
| `adc_sfdr_analysis` | `(d,files,out,runOptions)` | 当前20 MHz数据5抽1；全点同步分析或旧25 MHz数据须同时覆盖采样率、步长和用途字段 |
| `adc_bandwidth_analysis` | `(d,files,out,runOptions)` | 直接字段或 `configOverride` 子结构 |
| `adc_power_scale_analysis` | `(d,files,out,runOptions)` | 同上；另支持 `powerSetpoints` |
| `adc_isolation_analysis` | `(d,files,out,runOptions)` | 驱动通道、频率、参考面、inputChannels 等 |
| `adc_inl_dnl_analysis` | `(d,files,out,runOptions)` | inputRadix、inputChannels、连续性和质量门槛等本次设置 |

### CSV 进制和结果含义

`inputRadix` 取 `'hex'`（十六进制）、`'decimal'`（十进制）或默认 `'auto'`。
这与14位补码配置不同：前者决定如何读文本，后者决定读出数值怎样解释正负号。
按 ILA 导出设置填写；无声明、无明确前缀的码值不再猜测进制。交互运行会提示选择，显式调用须补参数：

```matlab
options = struct('inputRadix','hex');
r = adc_sfdr_analysis(d, files, [], options);
r = adc_inl_dnl_analysis(d, files, [], options);
```

最终进制及数据列在 `evidence/input_decoding.csv`。INL/DNL 对每份文件核对采集接口，
表头不够时用 `options.inputChannels` 逐一声明；不同接口分开运行。

- SFDR 仍是 Hann 窗峰值频点法，可能受到音调位于 FFT 栅格中间的影响。DC 先排除再找基波；Nyquist 不再被排除出杂散搜索；重叠的 DC/基波窗口明确报错。
- THD 现在为谐波功率除以基波功率再取 dB。1%幅度谐波对应 −40 dB，旧版正40 dB是相反比值。旧25 MHz数据的5抽1估算边界保持不变。
- 带宽保留全部明细，但达到/超过 Nyquist、拟合退化或超码域幅值的点不参与交点计算。少于两周期标 `InsufficientCyclesFlag`；结果一律保留正式“暂不能判定”。
- 隔离度 `IsolationDb` 为未校正通道增益的码幅比。`ThresholdMet` 是数值过阈值；`Pass` 还受频率、驱动质量、已确认参考条件及正式开关限制。条件不足看 `FormalConclusion`，不能将未获准判断的 `Pass=false` 当作不合格。
- INL/DNL 是各有效记录共有码域的码密度结果，INL 为最佳拟合直线扣除后的结果。码覆盖不足保留曲线但标 `IncompleteCodeCoverage`；全覆盖也不自动证明源纯度、相位统计和非线性真值已验证。

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

默认结果按前述raw同级/其它目录内部results规则，子目录名为 `run_时间_ad9245_input_equiv_noise_1hz`，返回 `r.runFolder`。先看 `input_equiv_noise_summary.csv`，再看每接口ASD图、参数和source_manifest（PSD图与PSD列已移除以减轻结果负担）。部分记录已有完整性问题，必须检查每行状态和note；生成结果不能证明ADC本征噪声合格。

## 查看结果

先查看 summary CSV 中的数值、状态和说明，再查看 PNG。运行参数记录在 `analysis_parameters.csv`、`run_config.mat` 或结果 MAT 中；输入文件见 `run_manifest.csv` / `source_manifest.csv`。

程序运行成功不代表器件指标合格。SFDR 定义、带宽混叠、隔离度拟合质量和频率检查、噪声参考面等仍需核对；文件选择功能的测试不能替代这些检查。

## 报告刻度配置

本器件的报告刻度由 `private` 配置中的 `reportCalibration` 字段加载，统一保存在 `_shared/+converter/+calibration/reportCalibration.m`。完整数值、单位和缺失项见 [CALIBRATION.md](../CALIBRATION.md)。刻度分析入口仍根据所选数据重新拟合，不会用报告数值替换新测量结果。
