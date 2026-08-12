# Laser electrical-test MATLAB workflow

本目录保存超稳激光电控箱电性测试的当前分析入口。建议每次启动
MATLAB 后先完成路径设置：

```matlab
cd('F:\01_Laser\code\matlab\laser_analysis')
addpath(pwd)
setenv('LASER_TEST_DATA_ROOT', 'F:\01_data_laser\DATA')
paths = setup_laser_analysis();
```

`setup_laser_analysis` 会加入 `utilities`、全部正式 `01_workflows` 以及当前
专用工具目录；不会加入 `archive` 和 `ref`，从而避免历史同名脚本遮蔽
正式入口。默认值已按当前工作站适配；用户级环境变量仍可覆盖这些默认值。
执行后建议检查：

```matlab
disp(paths)
```

使用 `laser_latest_fit_summary('AD','JG15')` 或相应 DA/通道调用读取最新
复核过的 Vpp-Codepp 标定摘要。该函数有意绕过汇总工作簿里的历史峰值法
记录，避免不同标定口径混用。

默认根目录：

- 代码：`F:\01_Laser\code\matlab\laser_analysis`
- 数据和完整分析结果：`F:\01_data_laser\DATA`
- 报告：`F:\01_Laser\202607`
- 需求和测试说明：`F:\01_Laser\202607_上海_电2\测试参考文件_20260630`

可用 `LASER_TEST_CODE_ROOT`、`LASER_TEST_DATA_ROOT`、
`LASER_TEST_REPORT_ROOT`、`LASER_TEST_REQUIREMENT_ROOT` 覆盖默认根目录。
分析脚本不得把完整 CSV/PNG/MAT 结果写入 `01_正式报告`。

## 文件夹分类

根目录不再堆放分析入口。`s01-s35` 按测试任务放入以下目录，但文件名、
函数签名和调用命令保持不变；运行前只需执行一次
`setup_laser_analysis`。

| 目录 | 脚本 | 职责 |
|---|---|---|
| `01_workflows/01_data_conversion` | `s01` | Vivado ILA CSV 到统一电压 MAT |
| `01_workflows/02_exploratory_spectrum` | `s02` | 通用探索性 PSD/ASD |
| `01_workflows/03_calibration` | `s06-s08`、`s17/s19/s21/s23` | ADC/DAC 单点、多点及 AD9245 标定 |
| `01_workflows/04_noise_and_chain` | `s03-s05`、`s09-s11`、`s13-s16`、`s18/s20/s22/s24/s25` | 噪声、积分、链路折算和通道专项分析 |
| `01_workflows/05_dynamic_and_linearity` | `s26-s30` | SFDR、DNL/INL、隔离、温漂和 DAC DC |
| `01_workflows/06_stability_and_timing` | `s12`、`s31-s34` | ADEV/MDEV、相噪、RF 参考、延迟和低速 ADC |
| `01_workflows/07_manual_records` | `s35` | 阻抗、电源、时钟、DDR 和通信记录检查 |
| `+laser_analysis` | 公共函数 | 配置、需求表、读取器、拟合、频谱和证据包 |
| `utilities` | `laser_test_paths`、`laser_latest_fit_summary` | 根目录与已复核标定定位 |
| `tests` | MATLAB 测试 | 合成数据和只读兼容性验证 |
| `PDH_data_process` | 专项工具 | PDH/相噪历史专项处理，尚未并入正式入口 |
| `yang_scale` | 专项工具 | 外部标定辅助代码 |
| `archive` | 历史快照 | 只用于追溯，不加入正常 MATLAB path |
| `ref` | 参考实现/虚拟数据 | 只用于复核，不作为正式入口 |

查看当前可调用入口：

```matlab
paths = setup_laser_analysis();
workflowFiles = dir(fullfile(paths.codeRoot, '01_workflows', '**', 's*.m'));
sort(string({workflowFiles.name}))'
```

## Script routing

| Script | Use |
|---|---|
| `s01_convert_ila_to_pico_mat.m` | ILA CSV转换为电压MAT |
| `s02_analyze_pico_psd_asd.m` | 通用探索性PSD/ASD |
| `s03_calc_dac_integrated_noise_1k_100k.m` | DAC 1 kHz～100 kHz积分噪声 |
| `s04_separate_ad_da_noise.m` | 可选AD/DA PSD本底分离 |
| `s05_compare_ad_p1_p100_input_noise.m` | P=1/P=100总链路输入等效比较 |
| `s06_calibrate_ila_single_sine.m` | ADC单点诊断刻度 |
| `s07_calibrate_ila_multi_sine.m` | ADC多点Vpp–Codepp正式刻度 |
| `s08_calibrate_dac_multi_sine.m` | DAC多点Vpp–Codepp正式刻度 |
| `s09_analyze_ad_input_equiv_noise_new_flow.m` | ADC–FPGA–DAC总链路输入端等效PSD/ASD；默认不扣DAC/PICO本底 |
| `s10_analyze_adc_grounded_csv_input_noise.m` | ADC接地ILA码流输入等效PSD/ASD |
| `s11_analyze_dac_output_noise_metrics.m` | DAC ASD@1 Hz与积分噪声 |
| `s12_batch_allan_stability_analysis.m` | 频率计ADEV/MDEV与1 s稳定度 |
| `s13_analyze_ad9245_psd_asd_datasheet_scale.m` | AD9245手册刻度交叉核对 |
| `s14_analyze_ad2208_jg12_jg15_10m25m_noise.m` | JG12/JG15 100 MSPS、10～25 MHz正式噪声指标 |
| `s15_analyze_dac766_c1_noise_metrics.m` | DAC766 `C1_data/C1_time`噪声 |
| `s16_analyze_jg18_jg3_g100_1hz_noise.m` | JG18–G100–JG3 1 Hz总链路噪声 |
| `s17_calibrate_ad9245_x2g_scale.m` | AD9245 X2G 多点刻度兼容入口 |
| `s18_analyze_ad9245_x2g_jg3_g100_psd_asd.m` | X2G–G100–JG3 总链路 PSD/ASD |
| `s19_calibrate_ad9245_x3g_scale.m` | AD9245 X3G 多点刻度兼容入口 |
| `s20_analyze_ad9245_x3g_jg2_g100_psd_asd.m` | X3G–G100–JG2 总链路 PSD/ASD |
| `s21_calibrate_ad9245_x4g_scale.m` | AD9245 X4G 多点刻度兼容入口 |
| `s22_analyze_ad9245_x4g_jg32_g100_psd_asd.m` | X4G–G100–JG32 历史 record-limited 入口 |
| `s23_calibrate_ad9245_x1g_scale.m` | AD9245 X1G 多点刻度兼容入口 |
| `s24_analyze_ad9245_x1g_jg11_g100_psd_asd.m` | X1G–G100–JG11 总链路 PSD/ASD |
| `s25_analyze_ad9245_x4g_jg32_g100_psd_asd_updated.m` | X4G–G100–JG32 当前入口 |

## s01-s12 快速选择

| 任务类别 | 首选脚本 | 何时使用 |
|---|---|---|
| 格式转换 | `s01` | 将 Vivado ILA 十六进制 CSV 转成统一电压 MAT |
| 探索频谱 | `s02` | 快速查看任意电压时序的 PSD、ASD 和频段统计 |
| DAC 正式指标 | `s03`、`s11` | 计算带内积分噪声，或批量计算 ASD@1 Hz |
| AD/DA 链路比较 | `s04`、`s05` | 分离本底，或比较 P=1/P=100 输入等效噪声 |
| ADC 标定 | `s06`、`s07` | 单点诊断使用 `s06`，正式多点标定使用 `s07` |
| DAC 标定 | `s08` | 由多组 DAC code 和 Pico MAT 拟合 Vpp-Codepp |
| 总链路折算 | `s09` | 由 DAC 输出噪声折算 ADC 外部输入等效噪声 |
| ADC 接地噪声 | `s10` | 直接由接地条件下的 ILA CSV 计算输入等效噪声 |
| 频率稳定度 | `s12` | 批量计算频率计数据的 ADEV、MDEV 和 1 s 稳定度 |

选择原则：

- 不确定输入格式时，先查看对应脚本顶部的“输入要求”和参数区。
- 只想了解数据时优先 `s02`；正式输出优先使用有 CSV/MAT/PNG 导出的
  专项脚本。
- 标定流程先于输入等效换算。`s09`、`s10` 使用的斜率必须确认参考面。
- 需要扣除本底时，只能在 PSD 层处理，并保留负差值比例等审计信息。

## s01-s12 最小用法

以下路径均为示例。`F:\path\...` 必须替换为实际数据路径。

| 脚本 | 最小运行方式 | 必要输入 | 主要输出 |
|---|---|---|---|
| `s01` | `s01_convert_ila_to_pico_mat` | GUI 选择 ILA CSV | 每文件 MAT/CSV、合并 MAT、manifest |
| `s02` | `load(...,'A','Tinterval'); s02_analyze_pico_psd_asd` | 工作区 `A`，可选 `Tinterval/fs` | `summaryTable` 和图窗，不自动保存 |
| `s03` | 修改 `cfg.files` 后运行脚本 | 含 `A` 和采样率元数据的 MAT | 积分噪声 CSV/MAT |
| `s04` | 修改 `cfg.pairs` 后运行脚本 | 总链路 MAT 与 DAC 本底 MAT | 分离结果 MAT、汇总、PSD/ASD 图 |
| `s05` | 修改 P=1/P=100 文件后运行 | 两个参考面一致的 MAT | 对比 CSV/MAT、PSD/ASD 图 |
| `s06` | `s06_calibrate_ila_single_sine` | 一个 ILA 正弦 CSV 和已知输入幅度 | 单点结果、曲线 CSV 和拟合图 |
| `s07` | 设置 `S07_DATA_DIR` 后运行 | 多个文件名带 Vpp/dBm 的 ILA CSV | 正式标定证据包 |
| `s08` | 设置 `S08_DAC_DATA_DIR` 后运行 | 文件名带 `code_整数` 的 Pico MAT | DAC 正式标定证据包 |
| `s09` | 设置 `s09_cfg_override` 后运行 | 总链路 MAT、ADC/DAC 标定 | 完整频谱、汇总、参数、图和 MAT |
| `s10` | 设置 `adcGroundedNoiseCfgOverride` 后运行 | 接地 ADC ILA CSV 和 `L_ADC` | 每文件证据和批量汇总 |
| `s11` | 修改 `dataDir` 后运行脚本 | 目录内多个 Pico MAT | 带时间戳汇总和每文件频谱图 |
| `s12` | `output=s12_batch_allan_stability_analysis(files,outDir)` | 频率计 CSV/TXT | ADEV/MDEV、质量表、图和 MAT |

常用调用示例：

```matlab
% s02：先清理可能残留的工作区数据，再加载新文件。
clear A Tinterval fs
load('F:\path\replace_with_voltage.mat', 'A', 'Tinterval')
s02_analyze_pico_psd_asd

% s07：ADC 多点正式标定。
setenv('S07_DATA_DIR', 'F:\path\replace_with_adc_csv')
setenv('S07_INTERFACE', 'JG15')
setenv('S07_REFERENCE_PLANE', 'adc_input')
s07_calibrate_ila_multi_sine

% s08：DAC 多点正式标定。
setenv('S08_DAC_DATA_DIR', 'F:\path\replace_with_dac_mat')
setenv('S08_ANALYSIS_INTERFACE_NAME', 'JG3')
s08_calibrate_dac_multi_sine

% s09：临时覆盖数据和结果目录，不修改脚本默认配置。
s09_cfg_override = struct;
s09_cfg_override.totalMatFile = 'F:\path\replace_total.mat';
s09_cfg_override.outputDir = 'F:\path\replace_output';
s09_analyze_ad_input_equiv_noise_new_flow

% s10：直接分析一个接地 ILA CSV。
adcGroundedNoiseCfgOverride = struct;
adcGroundedNoiseCfgOverride.inputFiles = {'F:\path\replace_grounded.csv'};
adcGroundedNoiseCfgOverride.fs = 100e6;
adcGroundedNoiseCfgOverride.L_ADC_manual = 1.9e-5;
s10_analyze_adc_grounded_csv_input_noise

% s12：显式传入多个频率计文件。
files = {'F:\path\counter_1.csv'; 'F:\path\counter_2.csv'};
output = s12_batch_allan_stability_analysis( ...
    files, 'F:\path\allan_results');
```

## 输入数据契约

### 电压 MAT

`s02-s05`、`s09` 和 `s11` 的常见 MAT 布局为：

| 变量 | 必需性 | 含义 |
|---|---|---|
| `A` | 必需 | 电压时序，通常单位 V |
| `Tinterval` | 推荐 | 相邻样本时间间隔，单位 s |
| `fs` | 可替代 | 采样率，单位 Hz |
| `Length` | 部分脚本使用 | 有效样本数，应小于等于 `numel(A)` |

如果同时存在 `Tinterval` 和 `fs`，多数脚本优先使用
`fs=1/Tinterval`。数据换成新采集格式时，先检查加载函数的优先级。

### ILA CSV

运行 `s01`、`s06`、`s07` 或 `s10` 前必须确认：

- `dataCol`：目标 ADC 数据列，列号从 1 开始。
- `validCol`：有效标志列；没有 valid 时保持空数组。
- `firstDataRow`：是否存在表头和 Vivado `Radix` 行。
- `dataRadix`：导出文本是 `hex` 还是 `decimal`。
- `adcBits`：ADC 或 FPGA 输出字的实际位宽。
- `outputCoding`：`twos_complement`、`offset_binary` 或 `unipolar`。
- `fs`：有效样本率，而不是未经核实的 FPGA 主时钟。

### 频率计 CSV/TXT

`s12` 默认把第 1 列视为 Hz 数据、没有时间列、记录间隔为 0.1 s。
不同仪器格式需要修改 `defaultFreqCol`、`defaultTimeCol`、
`defaultFreqScale` 和 `defaultTau0_s`。如果文件内有时间戳，应优先使用
时间列验证实际采样间隔。

## 单位和参考面

| 量 | 常用单位 | 说明 |
|---|---|---|
| 时域电压 `A` | V | 必须说明位于 ADC 输入、DAC 输出还是仪器端 |
| ADC/DAC 斜率 | V/code | 去均值噪声换算只使用斜率 |
| PSD | V^2/Hz | 不相关噪声和本底在这一层相加减 |
| ASD | V/sqrt(Hz)、uV/sqrt(Hz)、nV/sqrt(Hz) | 等于 `sqrt(PSD)` |
| 积分噪声 | Vrms 或 uVrms | 等于 `sqrt(integral(PSD))` |
| ADEV/MDEV | 无量纲 | 频率偏差除以 `centerFreq_Hz` 后计算 |

看到 `gain` 时先确认代码中的定义。当前常见约定是
`targetVoltage=measuredVoltage/gain`。如果数据已在目标参考面，增益应为
1。标定斜率和测量数据必须指向同一物理参考面。

## 推荐工作流

### ILA 码流快速频谱

```text
ILA CSV -> s01 -> A/Tinterval MAT -> s02 -> 频谱和频段统计
```

`s01` 的 `inputRangeVpp`、位宽和码型会直接决定后续所有电压结果。

### ADC-FPGA-DAC 输入等效噪声

```text
ADC 多点 CSV -> s07 -> L_ADC
DAC 多点 MAT -> s08 -> K_out
总链路噪声 MAT + L_ADC + K_out + G -> s09
```

正式结果默认保留 DAC/Pico 本底。只有获得同条件本底证据后，才启用
`s09` 的 `rawMat` PSD 相减。

### ADC 接地噪声

```text
ADC 多点标定 -> L_ADC
接地 ILA CSV + L_ADC -> s10 -> 输入等效 PSD/ASD
```

该流程绕过 DAC 输出链路，适合检查 ADC 与前端自身接地噪声。

### 频率稳定度

```text
频率计 CSV/TXT -> 核对列号、tau0、中心频率 -> s12
```

正式报告同时保留 Raw 与 Detrended，并说明异常窗口策略。

## 后续修改指南

新增通道或更换硬件时，按以下顺序修改和复核：

1. 先确认输入文件布局、数据列、位宽、Radix 和输出码型。
2. 确认采样率来自 `Tinterval/fs` 还是手动参数，并检查 Nyquist。
3. 确认时域量的物理单位和参考面，再设置 `gain` 或标定斜率。
4. 调整 Welch 窗、重叠率和 NFFT 后，记录实际频率分辨率。
5. 调整指标频段时，同步检查频段覆盖和限值单位。
6. 更换标定结果时，成组保存 summary、measurements、参数、图和哈希。
7. 修改本底处理时，只改 PSD 流程，并保留负差值比例和原始结果。

注释维护规则：

- 新增配置字段时，在字段旁写清单位、默认值来源和允许取值。
- 新增本地函数时，至少写一行“职责 + 输入输出”说明。
- 复杂换算要解释物理含义和参考面，不要只复述代码操作。
- 改变公式、阈值或数据筛选时，必须同步更新文件头部和 README。
- 示例路径使用明确的 `replace_...` 占位，避免被误当成正式数据。

## 常见问题排查

| 现象 | 优先检查 |
|---|---|
| 找不到文件或仍访问旧盘符 | `LASER_TEST_DATA_ROOT`、`LASER_TEST_REQUIREMENT_ROOT`、脚本内固定路径、文件夹名称 |
| `s02` 分析了错误数据 | 工作区残留的 `A/Tinterval/fs`；先执行 `clear` |
| 波形出现大跳变 | `dataRadix`、`adcBits`、`outputCoding` 是否匹配 |
| 电压整体按固定比例偏差 | `inputRangeVpp`、`gain`、`L_ADC/K_out` 和参考面 |
| 频段显示 `OUT_OF_RANGE` | 采样率和 Nyquist 是否覆盖频段上限 |
| 无法可靠给出 ASD@1 Hz | 记录时长和 Welch 分辨率是否达到约 1 Hz |
| PSD 相减出现大量负值 | 本底是否同条件、增益是否一致、噪声是否可视为不相关 |
| ADEV/MDEV 整体比例异常 | `centerFreq_Hz`、频率单位和 `tau0` 是否正确 |
| CSV 无法解析 | 列号、表头、Radix 行、编码和 valid 值 |
| 输出 CSV 无法覆盖 | 文件可能被 Excel 打开；关闭后重试或使用时间戳备份 |

## 工具箱依赖

- `s02-s05`、`s09-s11` 使用 `pwelch`，需要 Signal Processing Toolbox。
- `s01`、`s06-s08` 的核心标定流程使用 MATLAB 基础功能。
- `s12` 默认使用内置 ADEV/MDEV；只有显式启用 `allanvar` 时才需要
  提供该函数的相应工具箱。
- 工具箱状态可用 `ver`、`license('test',...)` 和
  `matlab.codetools.requiredFilesAndProducts` 辅助检查。

正式规则和完整选择表见 `$laser-electrical-data-analysis` 技能。

## s26-s35 CW 正式测试入口

`s26-s35` 是基于两份公开测试细则新增的离线分析入口。需求表来源固定为：

- 数字锁定板：SHA-256
  `BCA172A43422FC965EB5131FDF7B221E57D77819EAC1BF19502CAE3D6355BF26`
- 延迟驱动板：SHA-256
  `9C5FDDBDAAAB3EABA824C64523A61392B5220F16BDD6C21A6FBFC8DC1193B630`

CW 需求已经录入 `laser_analysis.requirement_profile`。GS 仅建立配置结构，
`formalEnabled=false`，在通道和接口映射完成复核前不能用于正式验收。

| 入口 | 测试任务 | 核心结果 |
|---|---|---|
| `s26` | ADC 动态性能 | SFDR、主频/最大杂散、幅相频响、-3 dB/-45°、削顶、1 dB 压缩 |
| `s27` | ADC 码密度线性 | sine-histogram DNL、端点/最佳拟合 INL、缺码和码覆盖 |
| `s28` | ADC/DAC 通道隔离 | aggressor-victim 隔离矩阵、最差组合、40 dB 判定 |
| `s29` | 温度漂移 | `uV/degC` 回归、95% 置信区间、迟滞和循环重复性 |
| `s30` | DAC DC 传输 | 输出范围、步进、静态 INL、单调性、饱和和负载电流 |
| `s31` | 相位噪声 | 1 Hz/100 kHz 取值、分辨率、底噪裕量和完整 `L(f)` |
| `s32` | 射频参考 | 功率、谐波抑制、ADEV/MDEV 和 1 s/10000 s 覆盖 |
| `s33` | 环路硬件延迟 | 50% 阈值逐边沿延迟、median/P95/max 和分辨率 |
| `s34` | 低速 ADC/遥测 | ADC128 RMS、AD677 ASD/采样率/频响、遥测误差 |
| `s35` | 人工功能记录 | 阻抗、电源、时钟、复位、DDR、RS422/LVDS 结构化检查 |

### 统一调用

所有入口使用同一种调用方式。示例路径必须按实际数据替换：

```matlab
cfg = laser_analysis.make_test_config( ...
    "digital_lock", "CW", "adc_sfdr");
cfg.manifestFile = "F:\path\replace_manifest.csv";
cfg.outputDir = "F:\path\replace_output";
result = s26_analyze_adc_dynamic_performance(cfg);
```

将最后一行替换为对应入口即可：

```matlab
result = s27_analyze_adc_code_density_linearity(cfg);
result = s28_analyze_channel_isolation(cfg);
result = s29_analyze_temperature_drift(cfg);
result = s30_analyze_dac_dc_transfer(cfg);
result = s31_analyze_phase_noise_compliance(cfg);
result = s32_analyze_rf_reference_compliance(cfg);
result = s33_analyze_loop_delay(cfg);
result = s34_analyze_low_speed_adc_telemetry(cfg);
result = s35_validate_manual_functional_records(cfg);
```

每次运行生成独立证据目录，包含 `parameters.csv`、`summary.csv`、
`details.csv`、`full_curve.csv`、`source_manifest.csv`、
`requirement_conflicts.csv`、图片和 `result.mat`。结论只使用
`满足/不满足/暂不能判定/未测试`。

### Manifest 契约

通用 CSV 列如下。未参与当前测试的列可以留空，但不能用文件夹名代替物理参数：

| 字段 | 含义 |
|---|---|
| `case_id/channel/source_file/format` | 用例、通道、源文件和 `mat/csv/ila_csv/tim` |
| `fs_hz/data_column/time_column/reference_column` | 采样率和数据列配置 |
| `radix/bits/coding/first_data_row` | ILA 码流格式 |
| `stimulus_frequency_hz/stimulus_level/stimulus_unit` | 激励频率和幅度 |
| `load_ohm/temperature_c/cycle/direction` | 负载、实测温度和温循信息 |
| `reference_plane/data_role/requirement_id` | 参考面、数据职责和准确需求行 |
| `tau0_s/center_frequency_hz/carrier_frequency_hz` | 稳定度与相噪时基 |
| `aggressor_channel/victim_channel/cable_skew_s` | 隔离和延迟配对 |
| `calibration_slope_v_per_code/calibration_source` | 码到电压标定及来源 |
| `code_value/reference_value/measured_value` | DC 码扫、遥测或人工标量 |

最小 ADC SFDR manifest 可以由 MATLAB 创建：

```matlab
manifest = table("SFDR01", "JG15", ...
    "F:\path\replace_capture.mat", "mat", 100e6, 15e6, ...
    "JG15 external ADC input", ...
    'VariableNames', {'case_id','channel','source_file','format', ...
    'fs_hz','stimulus_frequency_hz','reference_plane'});
writetable(manifest, "F:\path\replace_manifest.csv");
```

MAT 输入优先识别 `A/Tinterval` 和 `C1_data/C1_time`；其他变量名通过
`data_variable/time_variable/reference_variable` 指定。ILA 必须显式给出
位宽、码型和 Radix。TimeLab `.tim` 使用 `TIC` 时间误差块，相噪换算仍需
明确 `tau0_s`；嵌入的 `Input Freq` 可作为载频证据。

### 计算口径

- `SFDR=10log10(Pfund/Pmax_spur)`，谐波不排除，仍属于 spur。
- `DNL[k]=Nactual[k]/Nideal[k]-1`；INL 同时输出端点法和最佳拟合法。
- 隔离度为 `20log10(Aaggressor/Avictim)`，两通道使用同频正弦拟合。
- 频响为 `20log10(A(f)/Aref)`；只有同步参考通道才能给出传递相位。
- 温漂是稳态电压对实测温度的回归斜率，不使用温箱设定目录名。
- 积分噪声是 `sqrt(trapz(f,PSD))`，不得积分 ASD。
- 时间误差相噪使用 `phi(t)=2*pi*f0*x(t)` 和
  `L(f)=10log10(Sphi(f)/2)`。
- 延迟使用双通道 50% 阈值线性插值，并扣除实测 `cable_skew_s`。

缺少采样率、参考面、必要标定、负载或 `tau0` 时，不会产生“满足”结论。
Nyquist 不覆盖、相噪偏移不覆盖、1 Hz 分辨率不足或延迟分辨率不足时，
统一输出“暂不能判定”。

### CW 推荐工作流

```text
ADC/DAC 正式标定：s07 / s08
        -> manifest 填入标定来源和参考面
        -> s26 / s27 / s28 / s30

相噪仪 CSV 或 TimeLab：s31
频率计 CSV + 明确 tau0：s32
双通道阶跃/方波：s33
ADC128 / AD677 / 遥测：s34
人工记录表：s35
```

旧流程仍保留：`s01 -> s02` 用于 ILA 转换和探索；`s07/s08 -> s09`
用于总链路输入等效噪声；`s10` 独立处理 ADC 接地噪声；`s12` 用于通用
频率稳定度分析。

### 尚未裁决的需求冲突

以下内容保留在需求表中，脚本不会自行选择：

- 延迟板 DAC 噪声存在 `12 uV/sqrt(Hz)、1 mVrms` 与
  `75 uV/sqrt(Hz)、120 uVrms` 两组限值。
- 数字锁定板 DDR 容量存在 `1.2 GB` 与 `320 MB`。
- 延迟板 SFDR 步骤写 25 MHz，但采样率为 20 MSPS，分项表写
  1/5/10 MHz。
- 数字锁定板提出 `-45° > 2 MHz`，现有步骤只记录幅频。
- 单个满量程 DAC 正弦不能给出静态 INL，必须执行 DC code sweep。
- 数字锁定板时钟功率出现 `0–5 dBm`、`0–3 dBm` 和 `-5–5 dBm`。
- `AD766/DAC766` 器件名称仍需硬件资料确认。

冲突需求、方法缺口或 GS 未复核项只能给出“暂不能判定”。

## AD9245 公共接口

`s17`～`s25` 保留直接运行方式，但实际算法已路由到 `+laser_analysis`：

```matlab
cfg = laser_analysis.ad9245_calibration_config("X1G");
cfg.outputDir = tempname;
calibrationResult = laser_analysis.run_ad9245_scale_calibration(cfg);

cfg = laser_analysis.ad9245_noise_config("X1G", "current");
cfg.outputDir = tempname;
noiseResult = laser_analysis.run_ad9245_g100_psd_asd(cfg);
```

- `ad9245_calibration_config` 固定 X1G/X2G/X3G/X4G 的 ILA 数据列和有效标志列。
- `ad9245_noise_config` 固定 X1G–JG11、X2G–JG3、X3G–JG2、X4G–JG32 的数据与校准来源。
- 两个运行函数均返回统一 `result`，包含配置、源文件、校准来源、拟合/频谱、汇总表和输出文件。
- 试运行必须覆盖 `cfg.outputDir`，或在运行旧包装脚本前设置环境变量 `LASER_ANALYSIS_OUTPUT_DIR`。
- `s22` 仅保留历史短记录证据语义；当前 X4G 分析使用 `s25`。

## PSD/ASD defaults

- 真实码流必须先确认 radix、位宽和编码。
- 去均值后计算一侧Welch PSD，PSD单位 `V^2/Hz`，ASD为 `sqrt(PSD)`。
- 宽带噪声默认从 Hann、100段、50%重叠开始；正式结果必须记录实际窗口、NFFT、段数和分辨率。
- 指标频段至少统计中位数、均值、95%分位、最大值及最大值频率，并用全记录谱筛查窄带杂散。
- 积分噪声计算 `sqrt(integral(PSD))`，不得直接积分ASD。

## Calibration rules

ADC和DAC主刻度统一使用：

```text
Vpp = k * Codepp + b
```

- `s07`输出的同一时间戳 parameters、summary、measurements、fit/residual plot、MAT必须成组使用，并记录各输入CSV的SHA-256。
- `s08`输出的同一时间戳 summary、measurements、plot、MAT必须成组使用；用于正式分析前同样补齐源文件清单与哈希。
- 当前AD2208接口端原始刻度数据位于 `F:\01_data_laser\DATA\SZSD_AD2208\20260716_AD2208_scale`；正式使用前仍需确认与已复核逐通道结果成组对应。
- `F:\01_data_laser\DATA\AD_DA_calibration_table.xlsx` 中AD行仍是历史峰值法结果，未核对方法前不得覆盖当前Vpp–Codepp结果。
- JG12/JG15/JG18当前斜率已折算到板外输入接口，噪声换算不得再次除以1.8。
- 去均值PSD/ASD只使用斜率，截距不参与频谱缩放。

## Current formal flows

### JG12/JG15 10–25 MHz

Use `s14`. Input is the two 100 MSPS ILA CSV files under `SZSD_AD2208\20260716_AD2208_noise`. It produces Welch PSD/ASD, full-record spur screening, statistics, quality tables, figures, and MAT output.

### JG18 1 Hz

Use `s16`. It uses the JG18 external-interface ADC slope, JG3 DAC slope and FPGA gain 100, does not subtract DAC/PICO background, and exports window-sensitivity and segment-stability evidence.

### ADC–FPGA–DAC total chain

Use `s09`. Default `dacBaselineMode='none'` and formula:

```text
S_ADC,in,eq(f) = S_out,total(f) * [L_ADC/(G*K_out)]^2
```

Only set `dacBaselineMode='rawMat'` when matched DAC/PICO baseline evidence exists. PSD may be subtracted; ASD may not.

## Output handoff

Each formal analysis should export parameters CSV, summary CSV, full PSD/ASD CSV, readable figures, reproducible MAT, source hashes, calibration provenance and one of `满足/不满足/暂不能判定/未测试`. The report consumes these outputs and must not recalculate data inside the DOCX edit routine.

## Directory responsibilities

- `setup_laser_analysis.m`：唯一根目录启动入口，负责加载正式分类路径。
- `01_workflows`：按任务域分类的 `s01-s35` 正式入口。
- `+laser_analysis`：可复用配置与核心算法，不作为一次性脚本直接编辑。
- `utilities`：路径配置与已复核标定查找，不包含一次性分析。
- `archive/20260723_pre_refactor`：`s17`～`s25` 重构前原始版本，只用于追溯。
- `archive/20260723_s09_merge_review`：`s09` 的 base/ours/theirs/current 四版本与哈希记录。
- `ref`：历史参考实现和参考数据；使用前必须重新核对输入格式、采样间隔和标称频率。
- `result`：历史或局部结果，不自动等同于当前正式证据。
- 正式完整证据包放在 `F:\01_data_laser\DATA` 下对应实验数据目录，不写入报告正文目录。

## Static check

```matlab
cd(paths.codeRoot)
files = dir(fullfile('01_workflows', '**', 's*.m'));
for k = 1:numel(files)
    filePath = fullfile(files(k).folder, files(k).name);
    issues = checkcode(filePath, '-id');
    fprintf('%s: %d issue(s)\n', filePath, numel(issues));
end
packageFiles = dir(fullfile('+laser_analysis', '*.m'));
for k = 1:numel(packageFiles)
    path = fullfile(packageFiles(k).folder, packageFiles(k).name);
    issues = checkcode(path, '-id');
    fprintf('%s: %d issue(s)\n', path, numel(issues));
end
```

Never run a script containing Git conflict-marker lines (`<<<<<<< branch`, a line containing only `=======`, or `>>>>>>> branch`). Decorative comment separators are not conflict markers.

## Refactor validation

With a valid MATLAB license, run:

```matlab
cd(paths.codeRoot)
addpath(fullfile(paths.codeRoot, 'tests'))
report = run_ad9245_refactor_validation();
rmpath(fullfile(paths.codeRoot, 'tests'))
```

The validation writes only under `tempname`, compares available reviewed
summaries with `max(1e-15, 1e-10*abs(reference))`, and removes the temporary
tree on completion.
