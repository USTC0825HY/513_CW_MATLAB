# MATLAB 可视化分析桥验证记录

验证日期：2026-10-20。平台主体基线：`ade413ce0a57017af8316079132a79cf8a67180e`；主库基线：`1ed05b8`。主体基线之后补充了参考点、异常点和 ConstantLine 的显示适配，最终源文件校验值见本目录 SHA-256 清单。运行环境为 MATLAB `25.2.0.2998904 (R2025b)`、Windows。原有指标公式、筛选阈值、private 数值、刻度 CSV 和黄金基线均保持原样。

## 结果

| 检查 | 实际结果 |
|---|---|
| 现有完整单元/集成回归 `run_all_tests` | **228 通过，0 失败，0 未完成**；测试累计 657.016649 s |
| 26 个入口的配置适配 | 全部读取成功；配置来自原 private，通过六个薄适配器访问 |
| AD2208 ILA 噪声 | 桥与直接入口 summary 数值一致；独立 `pwelch` PSD 复算通过 |
| DA9726 电压噪声 | 桥与直接入口 summary 数值一致；独立 1 Hz ASD、积分 RMS 复算通过 |
| AD2208/AD9245/AD677 PICO 联合噪声 | 三种入口形式均以合成 MAT 实跑，生成实际表格、曲线和配置 |
| DA9726 直流输出电压 | 合成台阶斜率核对通过，保留原 CSV/FIG 输出布局 |
| AD2208 刻度 | JSON `powerSetpoints` 记录转 table、basename/绝对路径匹配和已知斜率核对通过 |
| AD2208 带宽/刻度清单接入 | Python manifest 与手工选文件分别调用真实 MATLAB；8点扫频、3点扫幅的结果表及曲线数值逐项一致 |
| 十进制/十六进制预览 | 同一码序列预览一致；`0000/7FFF/8000/FFFF` 解码为 `0/32767/−32768/−1` |
| 输出序列化 | 中文、普通字符标题、单点曲线数组、单列热图嵌套数组通过 |
| 图形标记和参考线 | 黑方块参考点、红叉异常点、−3 dB水平虚线及频带竖直点线的数值、颜色、标记和线型通过 |
| 新增 MATLAB 文件静态检查 | 18 文件完成 `checkcode`；无语法错误。运行代码无诊断，测试文件保留 1 条 `isscalar` 性能建议 |

本次通过平台桥实际运行 **8 个不同入口**。其他 **18 个入口完成目录、函数签名和默认配置适配检查**，本次未逐一通过桥处理数据。现有 228 项测试另行覆盖原库的单元与集成行为；它们与“26 个平台入口逐个实跑”分别记录。详见 [26 入口矩阵](ENTRY_MATRIX_20261020.csv) 和 [逐项回归记录](REGRESSION_20261020.csv)。

本次全部新增输入为合成夹具，未连接仪器，也未新增板级测量结论。`status="success"` 表示分析任务执行成功；正式测量判定继续保留在原结果表的状态列中。

## 数值检查

AD2208 ILA 使用 131072 个整数码、100 MHz 采样率、原单段窗与 NFFT 配置，选择鉴定件 ADC1_JG15 刻度。桥结果与直接调用原入口的 summary 数值一致；以同一原始码序列和实际采用斜率独立构造电压，再调用 `pwelch`，PSD 绝对误差小于 `1e-20 V²/Hz`。同一码流的十进制和十六进制 CSV 使用同一读取内核，预览值逐点相同。

DA9726 噪声夹具为 2048 S/s、20 s、多变量 MAT（A/B）；显式选择 A。原默认电压增益 100，测试积分频带显式设为 10～800 Hz，适配这份小型夹具的 Nyquist 范围。独立按电压除 100、去均值、原 Hann/Welch 设置计算，1 Hz ASD 和积分 RMS 与导出值的绝对差均小于 `1e-10`（分别以 μV/√Hz、μVrms 为单位）。此频带是软件测试条件，器件原默认 1 kHz～100 kHz 保持原样。

DA9726 直流台阶采用已知 `1e-4 V/code` 斜率，拟合偏差小于 `1e-12 V/code`。AD2208 刻度使用 JSON 设定值记录，已知斜率 `2e-5 V/code`，偏差小于 `1e-8 V/code`；原入口按自己的范围规则选点，平台保留其选点结局。

PICO 三入口的这轮检查验证调用、板型/接口传入和输出结构，未另行独立复算三套联合换算数值。原联合噪声数值规则的回归属于上述 228 项既有测试。

另以 Python 端的 manifest 接入和手工选文件进行四次真实 MATLAB 调用：AD2208 带宽各8个频点，AD2208刻度各3个幅度点。两种入口使用同一文件顺序、输入哈希及显式条件，带宽表、刻度/动态范围表和曲线数值逐项相同。

这组刻度同时确认了一个原内核的浮点边界行为：`calculatePowerScale.m` 第136～145行将自动上限由 dBm 换回 Vpp，再直接进行闭区间比较；该批上限为 `1.1999999999999997 Vpp`，输入设定值为 `1.2 Vpp`，差值为 `2.220446049250313e-16 Vpp`。因此3个选中点中有2个参与拟合，1.2 Vpp点被记为范围之外。manifest和手工路径保留相同结局。本轮没有调整原筛选阈值或比较公式；范围比较的数值容差列为后续独立开发事项。详细数值见下方 `existing_boundary_observation.json`。

## 参数、路径与输出边界

- 文件、输出目录、板型、PICO 接口和变量均通过任务明确传入。非交互缺少板型或接口时返回错误；这两个错误检查没有创建结果目录。
- DAC 电压噪声的配置采样率仅为历史参考元数据，平台将其显示为只读；实际分析仍由每个 MAT 的 `Tinterval/fs` 确定。
- DAC 隔离度要求显式配对清单；DA766 十六进制刻度保持原“第四参数为数值频率”的签名。AD9245 PICO 保持原三参数调用。
- 带宽文件名缺少频率标记时，桥返回缺少输入条件。来自采集 manifest 的设定值及文件名条件应先核对后传入；桥不从波形猜测激励频率。
- 保存的 FIG 曲线在显示层可抽取为包络点。正式指标仍由原入口读取全部样点计算。
- 新增输出位置和原始输入严格分开。已有历史结果未移动或覆盖。DC 输出电压继续使用原布局，桥没有为它补造统一 XLSX。
- 原精简表字段直接来自报告层。部分刻度表仍显示 `Vpp/CodePp`；本轮保留其原标签与码幅定义。通用 `raw` 文件名在部分原结果表中可能成为接口标签，需利用原入口支持的明确接口映射或采用可追溯的接口文件名。此处记录来源层的显示限制，本轮未改动原报告层。
- 部分旧配置字段只供记录，平台不会把 MAT 的参考采样率展示成实测采样率；未支持的选项明确报错。界面应只提交实际修改字段，避免将 `null` 自动推导占位当作新参数。

## 复现命令

在全新派生目录中运行：

```matlab
addpath('CW_513_ANALYSIS/tools/platform/tests');
run_platform_smoke('新的测试目录/smoke');
run_platform_contract_tests('新的测试目录/contracts', ...
    '新的测试目录/smoke/synthetic_inputs/JG18_noise.mat');
run_platform_output_tests('新的测试目录/output_checks');
```

原有回归：

```matlab
restoredefaultpath;
addpath('CW_513_ANALYSIS/tests');
results = run_all_tests();
```

使用绝对路径或先进入当前库。测试不得与其他器件目录的同名函数混用。平台每次调用会选择对应器件路径并在结束时恢复调用者路径。

## 证据位置

集中临时证据根：`F:/01_Laser/.codex_work/20261020-cw-analysis-platform/matlab`。

| 文件/目录 | 用途 |
|---|---|
| `regression.log`、`regression.mat`、`regression_summary.json` | 原有 228 项完整回归及精确统计 |
| `smoke2.log`、`smoke2/platform_smoke_report.mat` | ILA/DAC 噪声数值一致性检查；该次跳过默认配置重复检查 |
| `smoke2/adc_response_display.json`、`smoke2/dac_response_display.json` | 修正标题后的同结果可视化响应 |
| `contracts.log`、`contracts/default_contracts.mat`、`contracts/contract_report.mat` | 26 默认值、特殊调用、PICO/DC/刻度检查 |
| `contracts/pico_1.json`～`pico_3.json`、`dc.json`、`power.json` | 5 项补充实跑响应 |
| `output_checks/output_contract_report.json` | 最终文本、数组、十六进制边界及 18 文件静态诊断 |
| `marker_reference_checks/figure_response.json`、`output_contract_report.json` | 显示适配补丁的真实MATLAB FIG检查：单点标记、颜色、水平/竖直参考线；18文件静态检查仍无运行代码诊断 |
| `../python_backend/manifest_integration/integration_report.json` | 带宽与刻度的 manifest/手工四次实跑、哈希和表图逐值一致性，`all_passed=true` |
| `../python_backend/manifest_integration/power_scale/existing_boundary_observation.json` | 原刻度范围上沿的浮点比较观测及实际参与拟合点数 |
| 各运行目录的 `evidence` | 原始输入 SHA-256、实际配置、版本、日志、完整数值与任务记录 |

初次带入测试在 ADC 已运行后因测试自己的频谱文件通配符不匹配停止；修正为原输出 `*_PSD_ASD.csv` 后完整复算通过。测试过程中发现 FIG 标题字符处理问题，修正在平台显示适配层，并以单点/热图测试及同一已保存 FIG 重导核对。

最终图形检查发现 MATLAB 的 `plot(...,'ks')`、`plot(...,'rx')` 对象虽然属于 line，其 `LineStyle` 为 none。显示层现将这类对象输出为 scatter，并保留原 marker、RGB颜色和线型；`xline/yline` 的 ConstantLine 则导出保存时轴范围内的实际参考线坐标。小型 FIG 逐项验证了黑方块、红叉、`y=−3` 和 `x=1.5`，不涉及指标重算。

轻量证据随源码保留：[入口矩阵](ENTRY_MATRIX_20261020.csv)、[228 项测试结果](REGRESSION_20261020.csv)、[平台源码哈希](PLATFORM_SOURCE_SHA256_20261020.csv)。波形、完整频谱和结果图留在上述派生目录中。
