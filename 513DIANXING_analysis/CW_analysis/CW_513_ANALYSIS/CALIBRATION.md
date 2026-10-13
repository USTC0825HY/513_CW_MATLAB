# 鉴定件与电性加强件刻度配置

2026-10-12起，五个器件的刻度统一维护在 [`_shared/+converter/+calibration/report_calibrations_20261004.csv`](_shared/+converter/+calibration/report_calibrations_20261004.csv)。该 UTF-8 BOM 文件也是逐行对照表，共55条，含报告原文、表号、行号、方法说明和SHA-256。运行读取随代码发布的表，不依赖 Word 或某个历史 results 目录。

来源为两份 `20261004.docx` 报告的刻度表；系数按表内显示精度保存。报告未列的R²保持NaN；频率为近似值时另有frequencyNote，日期未注明时留空。噪声方法段中的旧系数不作为默认值。

更新正式刻度时，同步维护板型、接口、版本、斜率、截距、报告文件名/哈希及表行定位，并重新核对来源。临时试用新拟合值或重现旧结果，使用下方“用户指定刻度”参数，保留内置报告记录。

## 怎样选择

- 直接运行噪声入口：选文件、接口后，选择鉴定件或电性加强件。取消即结束；每次重新选择。
- 显式传文件：填写 `boardType='jianding'` 或 `'jiaqiang'`；路径名不参与板型判断。
- `calibrationState='current'`：优先改焊后，否则沿用该接口唯一记录及原状态。
- `calibrationState='before'` / `'after'`：精确要求该版本；缺失时列出可用版本并报错。
- `unspecified` 表示报告刻度表未注明改焊状态；它是记录状态，不是额外的调用选项。

2208和677的ILA/PICO使用第四参数选项；9245 PICO保留第三参数选项。PICO 的 `calibrationState` 选择ADC版本，DA9726 JG18配套所选板型的唯一记录，其自身状态保持未注明。

```matlab
% 在2208_hy目录：选文件的交互调用
adc_ila_noise_analysis
% 显式文件调用
o = struct('boardType','jianding','calibrationState','current', ...
    'inputRadix','decimal');
r = adc_ila_noise_analysis(dataFolder, selectedCsvFiles, outputFolder, o);
o = struct('boardType','jiaqiang','calibrationState','before', ...
    'interface','ADC6_JG24','fpgaGain',128);
r = adc_pico_noise_1hz_analysis(dataFolder,'capture.mat',outputFolder,o);

% 在9245_hy目录（第二参数是输出目录，第三参数是选项）
o = struct('boardType','jianding','selectedFiles',{{'capture.mat'}}, ...
    'interfaces',{{'X1G'}});
r = adc_input_noise_analysis(dataFolder,outputFolder,o);

% 查询：公共库已加载后
rows = converter.calibration.reportCalibration('AD2208','jiaqiang','current');
allVersions = converter.calibration.calibrationCatalog();
```

同名入口切换时先进入目标器件目录，使用 `which 函数名 -all` 确认路径；保留 private、相邻 _shared 和 noise_chain_hy。

## 数值与含义

统一单位 **V/code**。ADC拟合为 `Vpp=k×CodePp+b`，CodePp为码峰峰值；DA9726拟合横轴为无符号幅度设定字C_set；DA766横轴为`2×abs(signedCode)`。这些定义继续保存在每条记录，单位统一不改变横轴。

ILA：`v=(code-mean(code))*k_ADC`。PICO：`ASD_in=ASD_PICO*k_ADC/(abs(G_FPGA)*k_DAC)`，PSD乘该比例的平方。两者都不使用幅度拟合截距补偿噪声。DAC电压噪声继续按实测电压和放大增益处理，不乘报告刻度。

刻度扫描入口继续拟合新数据。SFDR、相对带宽、码比隔离度及INL/DNL不调用本表，无板型弹窗。

| 板型 | 器件 | 接口 | 原状态 | k（V/code） | b（V） |
|---|---|---|---|---:|---:|
| jianding | AD2208 | ADC1_JG15 | unspecified | 2.347136e-05 | 0.0003274615 |
| jianding | AD2208 | ADC2_JG17 | unspecified | 4.43806e-05 | -4.978057e-05 |
| jianding | AD2208 | ADC3_JG19 | unspecified | 2.37623e-05 | 0.0007470679 |
| jianding | AD2208 | ADC5_JG22 | unspecified | 2.378017e-05 | 0.0003932618 |
| jianding | AD2208 | ADC6_JG24 | unspecified | 3.788345e-05 | 0.003744282 |
| jianding | AD9245 | X1G | unspecified | 0.0001341131 | 0.002104214 |
| jianding | AD9245 | X2G | unspecified | 0.0001328759 | 0.00196628 |
| jianding | AD9245 | X3G | unspecified | 0.0001343665 | 0.001856673 |
| jianding | AD9245 | X4G | unspecified | 0.0001339039 | 0.002055146 |
| jianding | AD677 | 677_1 | unspecified | 0.000153605 | 0.076322 |
| jianding | AD677 | 677_2 | unspecified | 0.0001695154 | 0.083014 |
| jianding | DA9726 | DAC1_JG18 | unspecified | 0.0001014514 | -0.007722 |
| jianding | DA9726 | DAC2_JG20 | unspecified | 0.0001016721 | -0.007432 |
| jianding | DA9726 | DAC3_JG21 | unspecified | 0.0001014327 | -0.040317 |
| jianding | DA9726 | DAC4_JG23 | unspecified | 9.99497e-05 | -0.028059 |
| jianding | DA9726 | DAC5_JG25 | unspecified | 0.0001901345 | 0.020992 |
| jianding | DA766 | X11-5 | after | 0.0001562 | 0.0208 |
| jianding | DA766 | X11-5 | before | 0.0003039664 | 0.03613255 |
| jianding | DA766 | X11-6 | after | 0.0001578 | -0.0196 |
| jianding | DA766 | X11-6 | before | 0.0003052196 | 0.03397334 |
| jianding | DA766 | X11-7 | after | 0.0001577 | 0.0061 |
| jianding | DA766 | X11-7 | before | 0.0003045198 | 0.03244908 |
| jianding | DA766 | X12G | unspecified | 0.0003050184 | 0.03566069 |
| jianding | DA766 | X7 | unspecified | 0.0003050171 | 0.03549978 |
| jianding | DA766 | X77-7 | unspecified | 0.0003034652 | 0.03389897 |
| jianding | DA766 | X77-8 | unspecified | 0.0003040355 | 0.03295411 |
| jianding | DA766 | X9 | unspecified | 0.000304654 | 0.03335241 |
| jiaqiang | AD2208 | ADC1_JG15 | before | 2.368166e-05 | 0.0007018968 |
| jiaqiang | AD2208 | ADC2_JG17 | before | 4.4031937e-05 | 0.0037351032 |
| jiaqiang | AD2208 | ADC3_JG19 | before | 2.366545e-05 | 0.0006366048 |
| jiaqiang | AD2208 | ADC5_JG22 | before | 2.343259e-05 | 0.0006113425 |
| jiaqiang | AD2208 | ADC6_JG24 | after | 3.802132e-05 | 2.38797e-05 |
| jiaqiang | AD2208 | ADC6_JG24 | before | 1.932029e-05 | 0.001085465 |
| jiaqiang | AD9245 | X1G | unspecified | 0.0001335434 | 0.001499 |
| jiaqiang | AD9245 | X2G | unspecified | 0.000134355 | 0.001498 |
| jiaqiang | AD9245 | X3G | unspecified | 0.0001342798 | 0.001495 |
| jiaqiang | AD9245 | X4G | unspecified | 0.0001341605 | 0.001436 |
| jiaqiang | AD677 | 677_1 | unspecified | 0.000153251 | 0.0417323 |
| jiaqiang | AD677 | 677_2 | unspecified | 0.000170337 | 0.0641894 |
| jiaqiang | DA9726 | DAC1_JG18 | unspecified | 0.0001022947 | -0.010076 |
| jiaqiang | DA9726 | DAC2_JG20 | unspecified | 0.0001024988 | -0.01355 |
| jiaqiang | DA9726 | DAC3_JG21 | unspecified | 0.0001006405 | -0.009294 |
| jiaqiang | DA9726 | DAC4_JG23 | unspecified | 0.0001015706 | -0.009727 |
| jiaqiang | DA9726 | DAC5_JG25 | unspecified | 0.0001908012 | -0.002929 |
| jiaqiang | DA766 | X7 | unspecified | 0.0003040308 | 0.007843 |
| jiaqiang | DA766 | X9 | unspecified | 0.0003055024 | 0.00879 |
| jiaqiang | DA766 | X11-5 | after | 0.0001566572 | 0.02027 |
| jiaqiang | DA766 | X11-5 | before | 0.000304975 | 0.007733 |
| jiaqiang | DA766 | X11-6 | after | 0.0001575124 | 0.004347 |
| jiaqiang | DA766 | X11-6 | before | 0.0003050217 | 0.007508 |
| jiaqiang | DA766 | X11-7 | after | 0.0001571974 | -0.02008 |
| jiaqiang | DA766 | X11-7 | before | 0.0003044792 | 0.007427 |
| jiaqiang | DA766 | X12G | unspecified | 0.0003041937 | 0.007804 |
| jiaqiang | DA766 | X77-7 | unspecified | 0.0003039892 | 0.007415 |
| jiaqiang | DA766 | X77-8 | unspecified | 0.000305144 | 0.006154 |

## 自定义刻度与历史复跑

每次ADC端只选一种来源：ILA可用 `noiseCalibration` 或 `reportCalibration`（含channel、slopeVPerCode的结构体）；也可用 `adcCalibrationRows` 或旧格式工作簿 `calibrationWorkbook`。PICO入口接受后两种。工作簿继续读取“刻度参数”工作表，第3行起依次为器件、接口、数据组、斜率、截距、R²。

```matlab
% 2208/677 ILA：显式历史系数
cal = struct('channel','ADC1_JG15','slopeVPerCode',2.347136e-5);
o = struct('noiseCalibration',cal,'inputRadix','decimal');
r = adc_ila_noise_analysis(dataFolder,selectedCsvFiles,outputFolder,o);

% 2208 PICO：显式指定ADC和DAC两端，系数仅为调用示例
cal = struct('device','AD2208','interface','ADC6_JG24', ...
    'slope',3.802132e-5,'intercept',2.387970e-5,'r2',NaN);
o = struct('interface','ADC6_JG24','adcCalibrationRows',cal, ...
    'kDacVPerCodePp',1.022947e-4,'fpgaGain',128);
r = adc_pico_noise_1hz_analysis(dataFolder,'capture.mat',outputFolder,o);
```

自定义PICO刻度需要同时明确DAC：`kDacVPerCodePp`或`dacSummaryPath`二选一，后者为一条JG18刻度记录的CSV。保留字段名以兼容现有调用，显示单位为V/code。ADC工作簿与ADC结构体同时提供、DAC斜率与CSV同时提供会报来源冲突。内置ADC搭配自定义DAC时也会提示完整指定两端。自定义结果标为“用户指定刻度”，不带内置报告来源标记。

## 查看实际生效值

`结果汇总.xlsx`上方简要列板型及各接口版本。ILA在`evidence/report_calibration_rows.csv`和结果MAT中保存完整刻度；PICO在`evidence/selected_adc_calibration.csv`、`selected_dac_calibration.csv`和`result.mat`保存实际记录。最终配置的`calibrationSelection`含来源及选中记录。两份报告SHA-256、表/行定位与代码内目录表哈希保留用于追溯。

更改板型或系数后重新计算，噪声值会按上述比例变化。历史报告、历史输出保持原样。配置选择与合成数据回归验证的是软件行为，板级测量条件仍按各批记录解释。
