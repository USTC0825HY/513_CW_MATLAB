# AD2208/YB2208 分析程序

本目录基于 `9245_hy` 的 ADC 分析流程改造，适配 YB2208 CW 数据：16 bit、100 MHz、FPGA 已转换的有符号补码，CSV 第 4 列为 ADC 数据。

入口文件：

- `adc_sfdr_analysis.m`：SFDR/SNR/SINAD/THD/ENOB
- `adc_bandwidth_analysis.m`：输入频率响应、-3 dB 带宽、30 MHz dB 标注，
  并按 `f > 70 MHz`、阻带抑制度 `> 40 dB` 输出参考线和判定结果
- `adc_power_scale_analysis.m`：输入功率标定
- `adc_isolation_analysis.m`：通道隔离度
- `adc_inl_dnl_analysis.m`：正弦码密度 INL/DNL
- `run_ad2208_batch.m`：按 AD2208 数据树自动分组批处理
- `ad2208_build_input_coverage.m`：逐文件生成输入覆盖与 SHA-256 清单
- `audit_ad2208_results.m`：校验最新结果包及其输入哈希

运行批处理：

```matlab
run_ad2208_batch('F:\\01_Laser\\20260727_513test\\03_CW测试\\02_Data_测试数据\\513_CW_DATA\\AD2208');
```

原始 CSV 只读；结果写入对应指标和通道目录的 `results`。当前数据目录没有隔离度、噪声和时钟 CSV，因此批处理会记录为“未处理”，不会生成伪结果。

根目录汇总文件为 `AD2208_batch_summary.csv`、`AD2208_input_coverage.csv` 和 `AD2208_result_audit.csv`。指标没有给出验收阈值时，汇总仅报告测量值，不自行判定满足或不满足。

INL/DNL 分析会对每个 CSV 独立精细估频和拟合，再按每份记录的幅度、偏置和有效样本数混合理论正弦码概率。默认把多个 CSV 视为独立触发记录，不假设文件边界的样点或相位连续。`ADC_inl_dnl_capture_metrics.csv` 用于逐文件检查频率漂移、拟合残差、毛刺、削顶和是否纳入 INL/DNL；文件修改时间只用于观察整批记录随保存时间的慢漂移，不等同于硬件采样时间。只要有效记录比例未达到配置门槛，就不输出可用于判定的 INL/DNL 曲线。

分析一个目录下的全部 CSV：

```matlab
dataFolder = '完整的采集目录';
adc_inl_dnl_analysis(dataFolder, [], fullfile(dataFolder, 'results'));
```

只有采集系统明确保证文件间样点首尾无缝相接时，才把第四个参数设为 `true`：

```matlab
adc_inl_dnl_analysis(dataFolder, [], outputFolder, true);
```

通道映射依据现场说明：ADC1/JG15、ADC2/JG17、ADC3/JG19、ADC5/JG22、ADC6/JG24。模块索引由 CSV 表头识别，输出通道名称统一为 `ADCx_JGxx`。
