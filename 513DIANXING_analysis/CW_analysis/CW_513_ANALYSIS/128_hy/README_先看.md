# ADC128 带宽分析

运行 `128_hy/adc_bandwidth_analysis.m`，先选择同一通道的扫频CSV，再填写CSV相邻样点的采样率和码值列号。ADC为12 bit，原始码按unsigned 0～4095读取；默认第4列，请按CSV表头核对。建议导出十进制码。采样率没有默认值，不能照搬2208的100 MHz；若CSV保留ILA保持码，填写ILA记录时钟，若已按有效脉冲提取数据，填写提取后实际均匀更新率。本脚本不抽样，也不自动删除保持码。

```matlab
cd('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/128_hy');
clear adc_bandwidth_analysis;
adc_bandwidth_analysis
```

显式调用（Fs请先赋值为本次真实采样率，单位Hz）：

```matlab
settings = struct('sampleRate', Fs, 'adcDataColumn', 4);
r = adc_bandwidth_analysis(dataFolder, ...
    {'ADC128_100Hz.csv','ADC128_200Hz.csv','ADC128_400Hz.csv', ...
     'ADC128_1kHz.csv','ADC128_2kHz.csv','ADC128_4kHz.csv'}, [], settings);
```

文件名须包含注入频率，如100Hz、1kHz；每次每个频率选择一份CSV，不混通道或不同输入幅度。整个扫频过程保持输入Vpp、直流偏置、量程和接线不变。输入频率必须低于样点采样率的一半。

## 计算方法

与2208共用 `converter.adc.runBandwidth/calculateBandwidth`。先FFT估频，再优化正弦拟合频率，拟合 `a*sin(2*pi*f*t)+b*cos(2*pi*f*t)+c`。幅值取 `CodePp=2*hypot(a,b)`；c吸收直流偏置。读取时将原始码统一减2048，只做平移，不改变峰峰值，不把高于2047的原始码误解为负数补码。

全正正弦可以直接拟合；如果波谷触及0或波峰触及4095，会被近轨检查排除。默认1码余量，即存在原始码≤1或≥4094时排除该记录。不能因为输入全正就忽略削顶。

R²至少0.99、无近轨、频率一致的点参与带宽计算。频率误差容限为文件频率的2%与2个FFT频点间距的较大值。最低频3个有效点的CodePp中位数作为参考，响应为 `20*log10(CodePp/referenceCodePp)`；−3 dB交点在log10频率轴上线性插值，覆盖不足时不外推。这里输出码值峰峰值及相对dB；没有V/code刻度就不宣称输出单位为V。固定线性刻度在归一化比值中抵消。

结果沿用公共内核：`ADC_bandwidth_summary.csv`、`ADC_bandwidth_result.mat`、PNG/FIG、参数表、输入哈希和日志，写入新时间戳results目录。原始数据不覆盖。没有ADC128验收限值，正式结论为“暂不能判定”。当前入口验证使用合成数据，实际CSV表头和时基仍需按本次采集核对。
