# 当前单项入口与运行方法

本清单按当前磁盘源码核对，共 **25 个正式单项入口**：2208有7个、9245有6个、677有4个、9726有3个、766有4个、128有1个。完整源码分类、绝对路径、签名、依赖与SHA-256见 [SCRIPT_MATRIX.csv](SCRIPT_MATRIX.csv)；逐入口CSV见 [ENTRYPOINTS.csv](ENTRYPOINTS.csv)。脚本存在或测试通过，不代表全部实测方法已经验证。

## 先进入正确器件目录

同名函数要从相应器件目录运行。不要递归把整库、CW_513_CODE和多个器件同时加入MATLAB路径。器件private、相邻_shared和PICO用的noise_chain_hy都必须保留。

```matlab
root = 'F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS';
cd(fullfile(root,'2208_hy')); % 按下表换成对应器件
clear adc_bandwidth_analysis adc_power_scale_analysis adc_sfdr_analysis
which adc_bandwidth_analysis -all
```

每一行的函数名都可直接零参数运行，弹窗选择本次文件。PICO还需明确ADC接口；DAC隔离度还需选择驱动与受扰记录。取消文件或CSV进制选择不生成新结果。

表中的 `d` 是实际数据目录；`files` 是所选文件名cell，例如 `{'capture1.csv','capture2.csv'}`；`out` 是输出根目录，可用 `[]` 采用默认规则。下列命令是参数写法，示例文件与接口必须换成实际测量条件。

## CSV进制怎么设置

```matlab
adcOpts = struct('inputRadix','decimal'); % 实际为十进制时
% adcOpts = struct('inputRadix','hex');  % 实际为十六进制时
```

这是导出文本的进制，与位宽及有符号/无符号码制不同。未填写时为auto：仅采信明确CSV进制声明、0x前缀，或包含负号的合法十进制列。纯数字1000、无前缀03e8不能猜；交互运行会询问，显式运行会要求填写inputRadix。十六进制按配置位宽补码转换；unsigned仍减半量程转到分析中心。缺失、NaN/Inf、小数及超范围码会拒绝，不会静默删点。

确认结果存于本次config.inputRadixByFile，实际进制、来源、列号、位宽、转换规则和样点数进入解码证据。显式文件调用不弹进制对话框。

## 25个单项入口

| 目录 | 入口与用途 | 显式调用 | 主要数值表（成功后位于evidence） |
|---|---|---|---|

| `2208_hy` | `adc_bandwidth_analysis`<br>频率响应、−3 dB带宽 | `r = adc_bandwidth_analysis(d, files, out, adcOpts);` | `ADC_bandwidth_summary.csv` |
| `2208_hy` | `adc_power_scale_analysis`<br>CodePp→Vpp刻度、99%临界输入估计 | `r = adc_power_scale_analysis(d, files, out, adcOpts);` | `ADC_vpp_codepp_summary.csv; ADC_vpp_codepp_calibration.csv; ADC_critical_input_estimate.csv` |
| `2208_hy` | `adc_sfdr_analysis`<br>SFDR/SNR/SINAD/THD/ENOB | `r = adc_sfdr_analysis(d, files, out, adcOpts);` | `ADC_SFDR_summary.csv` |
| `2208_hy` | `adc_ila_noise_analysis`<br>ILA输入等效PSD/ASD和频带积分 | `r = adc_ila_noise_analysis(d, files, out, adcOpts);` | `<器件>_input_noise_summary.csv; <接口>_PSD_ASD.csv` |
| `2208_hy` | `adc_pico_noise_1hz_analysis`<br>PICO联合DA9726刻度的输入等效1 Hz ASD | `r = adc_pico_noise_1hz_analysis(d, matFile, out, struct('interface','ADC6_JG24'));` | `input_equiv_noise_summary.csv` |
| `2208_hy` | `adc_isolation_analysis`<br>ADC驱动/受扰隔离度 | `r = adc_isolation_analysis(d, files, out, adcOpts);` | `ADC_isolation_summary.csv` |
| `2208_hy` | `adc_inl_dnl_analysis`<br>正弦码密度INL/DNL | `r = adc_inl_dnl_analysis(d, files, out, false, adcOpts);` | `ADC_inl_dnl_summary.csv; ADC_inl_dnl_curve.csv; ADC_inl_dnl_capture_metrics.csv` |
| `9245_hy` | `adc_bandwidth_analysis`<br>频率响应、−3 dB带宽 | `r = adc_bandwidth_analysis(d, files, out, adcOpts);` | `ADC_bandwidth_summary.csv` |
| `9245_hy` | `adc_power_scale_analysis`<br>CodePp→Vpp刻度、99%临界输入估计 | `r = adc_power_scale_analysis(d, files, out, adcOpts);` | `ADC_vpp_codepp_summary.csv; ADC_vpp_codepp_calibration.csv; ADC_critical_input_estimate.csv` |
| `9245_hy` | `adc_sfdr_analysis`<br>SFDR/SNR/SINAD/THD/ENOB | `r = adc_sfdr_analysis(d, files, out, adcOpts);` | `ADC_SFDR_summary.csv` |
| `9245_hy` | `adc_input_noise_analysis`<br>PICO联合DA9726刻度的输入等效1 Hz ASD | `r = adc_input_noise_analysis(d, out, struct('selectedFiles',{{matFile}},'interfaces',{{'X1G'}}));` | `input_equiv_noise_summary.csv` |
| `9245_hy` | `adc_isolation_analysis`<br>ADC驱动/受扰隔离度 | `r = adc_isolation_analysis(d, files, out, adcOpts);` | `ADC_isolation_summary.csv` |
| `9245_hy` | `adc_inl_dnl_analysis`<br>正弦码密度INL/DNL | `r = adc_inl_dnl_analysis(d, files, out, adcOpts);` | `ADC_inl_dnl_summary.csv; ADC_inl_dnl_curve.csv; ADC_inl_dnl_capture_metrics.csv` |
| `677_hy` | `adc_bandwidth_analysis`<br>频率响应、−3 dB带宽 | `r = adc_bandwidth_analysis(d, files, out, adcOpts);` | `ADC_bandwidth_summary.csv` |
| `677_hy` | `adc_power_scale_analysis`<br>CodePp→Vpp刻度、99%临界输入估计 | `r = adc_power_scale_analysis(d, files, out, adcOpts);` | `ADC_vpp_codepp_summary.csv; ADC_vpp_codepp_calibration.csv; ADC_critical_input_estimate.csv` |
| `677_hy` | `adc_ila_noise_analysis`<br>ILA输入等效PSD/ASD和频带积分 | `r = adc_ila_noise_analysis(d, files, out, adcOpts);` | `<器件>_input_noise_summary.csv; <接口>_PSD_ASD.csv` |
| `677_hy` | `adc_pico_noise_1hz_analysis`<br>PICO联合DA9726刻度的输入等效1 Hz ASD | `r = adc_pico_noise_1hz_analysis(d, matFile, out, struct('interface','677_1'));` | `input_equiv_noise_summary.csv` |
| `9726_hy` | `dac_scale_analysis`<br>DAC正弦输出Vpp和码值刻度 | `r = dac_scale_analysis(d, files, out, dacOpts);` | `dac_scale_summary.csv` |
| `9726_hy` | `dac_noise_analysis`<br>DAC输出PSD/ASD，按配置启用积分 | `r = dac_noise_analysis(d, files, out, dacOpts);` | `dac_noise_summary.csv; <器件>_<记录>_ASD_spectrum.csv` |
| `9726_hy` | `dac_isolation_analysis`<br>DAC同频隔离度及矩阵 | `r = dac_isolation_analysis(d, pairs, out, dacOpts);` | `dac_isolation_summary.csv; dac_isolation_matrix_db.csv` |
| `766_hy` | `dac_scale_analysis`<br>DAC正弦输出Vpp和码值刻度 | `r = dac_scale_analysis(d, files, out, dacOpts);` | `dac_scale_summary.csv` |
| `766_hy` | `dac_scale_hex_analysis`<br>DA766十六进制正弦刻度 | `r = dac_scale_hex_analysis(d, files, out);` | `dac_scale_summary.csv` |
| `766_hy` | `dac_noise_analysis`<br>DAC输出PSD/ASD，按配置启用积分 | `r = dac_noise_analysis(d, files, out, dacOpts);` | `dac_noise_summary.csv; <器件>_<记录>_ASD_spectrum.csv` |
| `766_hy` | `dac_isolation_analysis`<br>DAC同频隔离度及矩阵 | `r = dac_isolation_analysis(d, pairs, out, dacOpts);` | `dac_isolation_summary.csv; dac_isolation_matrix_db.csv` |
| `128_hy` | `adc_bandwidth_analysis`<br>频率响应、−3 dB带宽 | `r = adc_bandwidth_analysis(d, files, out, adcOpts);` | `ADC_bandwidth_summary.csv` |

`matFile`是一份实际PICO MAT文件名；示例ADC6_JG24、677_1、X1G应换成本次真正采集的接口。不能靠文件名猜接口或放大倍数。

2208 INL/DNL第四参数仍为记录连续性布尔值，默认false表示每份CSV独立触发；进制等选项放第五参数。其他ADC CSV入口第四参数可传adcOpts，2208隔离度第四参数按字段覆盖配置。

`dacOpts=struct()`使用当前DAC配置；第四参数可覆盖hardwareGain、toneFrequencyHz等。766专用hex入口只有三个参数，固定1525 Hz、增益1、16位补码后CodePp=2×abs(signed code)；其他条件使用通用刻度入口显式配置。

DAC隔离度的pairs是struct/table/CSV配对清单，不能传普通文件列表。字段包括driven_file、victim_file、driven_variable、victim_variable、driven_label、victim_label、frequency_hz、reference_plane，值必须来自实际采集。两路同一增益在隔离度比值中相消；不同放大条件不能用一个共同hardwareGain代替。

## 默认参数与数据选择边界

- 当前参数以各器件private配置和入口覆盖为准。运行后的evidence/run_config.mat、参数表、input_decoding.csv记录实际使用值。
- 2208 ILA为100 MHz、单段131072点Hann、0重叠、NFFT131072，频点间隔约762.939 Hz；它不是PICO的1 Hz噪声。
- 9245 SFDR的源采样率、分析采样率、抽样步长须一起核对，不能只改一个数就认定是同步新采集。
- 677/128带宽零参数选文件；只给目录会扫描该目录CSV。默认按valid选通推导实际均匀样点率；显式有限sampleRate覆盖时，由调用者保证时基对应被保留的样点。
- 9726和766的噪声入口默认hardwareGain=100；两器件刻度和隔离度默认增益1，766专用hex刻度也为1。已补偿数据不要再次除100。ASD/RMS除幅度增益，PSD除增益平方。
- 2208/677 PICO每次一份MAT，固定DA9726 JG18斜率1.01451391294771e-4；9245使用独立固定值1.014514e-4。ADC刻度与FPGA增益也必须匹配当次条件。
- 9726噪声默认ASD-only；积分需显式启用并确认频带覆盖。766积分同样需要真实频带覆盖。

## 新结果放在哪里

```text
run_<时间戳>_<项目>/
  结果汇总.xlsx       日常查看的条件、单位、指标与状态
  *.png               日常查看的图片
  evidence/
    *.csv             摘要、明细、频谱、排除原因和来源清单
    *result.mat       可复算的数值结构
    run_config.mat    本次实际配置
    input_decoding.csv 实际进制/列/位宽/转换规则
    *.fig             可编辑图形
    日志、哈希、STATUS_SUCCESS.txt等
```

上述布局针对成功的新运行，历史结果不迁移。失败运行可能还未整理，以实际错误日志为准。状态success表示执行成功，不直接表示器件指标满足要求。

普通输入目录默认写其内部results；目录名raw时写raw同级results。677带宽默认使用数据目录同级results；128沿用普通results规则；2208 PICO写所选目录内部results。显式填写out最明确；程序仍在out下面新建时间戳目录，不覆盖历史结果。

当前IO定向测试共23项，覆盖双文件解码记录追加及双通道所选列识别；实际通过状态以最终实施报告和本次测试日志为准。方法、实际数据、工具箱与未覆盖条件不能仅凭该清单判断。
