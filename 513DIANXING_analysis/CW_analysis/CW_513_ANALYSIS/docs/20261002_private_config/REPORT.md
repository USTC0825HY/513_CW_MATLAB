# 六器件 private 配置优化与验收

日期：2026-10-02。基线提交：`e997818f937ceb8fb8d20c7c5b2d8488968a4951`，验证对象为该提交之上的当前工作区；本次未提交或推送。

## 结论与使用入口

保留26个单项入口：2208为7个、9245为6个、677为4个、128为1个、9726为4个、766为4个。没有新增批量分析入口，没有变更计算公式、原有筛选阈值、原始数据或历史结果。

日常使用先看[参数配置说明](../../CONFIGURATION.md)，再看器件目录原有 `README_先看.md`。全部入口实际签名、配置位置和特殊参数见[入口矩阵](ENTRY_CONFIG_MATRIX.csv)。

- 长期默认值改各器件 `private/*Config.m` 对应分支。
- 单次参数通过入口原有 `runOptions/configOverride/options` 传入；766十六进制刻度第四参数仍为数值频率，9245 PICO仍为三参数，2208 INL第四参数仍是连续性布尔值。
- 生效顺序为默认配置 → 本次覆盖 → 派生计算和校验。数据、文件、输出目录的非空位置参数优先。
- 常规运行看 `evidence/run_config.mat` 中的 `config` 和 `parameterSources`；PICO联合噪声查看结果MAT中的 `result.config`；9726直流输出查看运行目录 `run_config.mat` 中的 `options`。

## 配置归位清单

| 器件 | 本次调整 | 保持的数值和计算约定 |
|---|---|---|
| 2208 | PICO默认值归入 `pico_noise`，正式判定开关显式化，隔离度覆盖走校验 | ILA单段131072点；PICO增益128、目标0.2 Hz、50%重叠；原固定刻度 |
| 9245 | PICO归入 `pico_noise`；SFDR采样率在覆盖后计算；刻度范围选择、绘图默认值移入配置 | 20 MHz/5=4 MHz默认频率轴；原动态范围与99%临界输入方法；Vpp范围优先 |
| 677 | `input_noise`和`pico_noise`分开；说明字段移入metadata；记录ILA覆盖 | 当前两路斜率保持1.53251359250316e-4和1.70337125111340e-4 V/code；公共历史刻度独立保留 |
| 128 | 显式inputRadix；记录采样率来自调用者还是valid推导 | 12位unsigned、下沿处理、手动带宽换算和条件参数保持原样 |
| 9726 | scale/noise/isolation分支分开；新增内部output_voltage配置分支 | 刻度增益1、噪声增益100；原直流码序列、0.25 V边沿、0.05 s保持、0.02 V平台容差、201点平滑 |
| 766 | 分析分支分开；十六进制入口默认值归入scale_hex | 1525 Hz、增益1、512～65536码幅、补码后两倍绝对码幅；analysisId仍为scale |

六个bootstrapRuntime保留。未改变发布包的加载方式，也未重新制作发布包。

## 修复的参数生效问题

| 情况 | 原行为/风险 | 当前行为 |
|---|---|---|
| 9245 SFDR只改sampleRate | 派生分析速率可能保留旧值 | 自动按sampleRate/sfdrSampleStride更新；25 MHz/5得到5 MHz；显式不一致报错 |
| 9245刻度只改dBm范围 | Vpp优先，调用者修改可能没有作用 | 报错并说明同时设置powerRangeVpp=[]；完整旧配置同时含两字段时保留Vpp优先 |
| 9245入口范围/绘图设置 | 入口可能覆盖用户设置 | 作为配置默认值合并，临时覆盖保留 |
| 9245交互CSV进制 | 选完文件再判断交互状态，可能跳过基数提示 | 在选文件前记录交互状态 |
| DAC简化隔离度选择 | 共同增益被强制重置为1 | 保留显式共同增益；交互默认值来自配置；不新增两路独立增益 |
| 参数拼写或嵌套冲突 | 通用结构体合并允许静默接受 | 入口边界检查名称、给相近名称建议；混用外层算法字段和configOverride报错 |
| 已停用或其他指标参数 | 容易被误认为参与本项计算 | 合法旧字段保留复跑；已登记停用项和指标专用项给出不生效提示 |
| PICO配置采样率 | 历史参考速率可能被误认作实测 | 显式标注为兼容参考值；实际计算仍逐文件读取MAT时基 |
| 677短ILA记录 | 1 Hz下限容易误读为测到了1 Hz | 显示记录时长、实际频点和覆盖；新增coverage MAT，不改频谱和判定阈值 |

通用mergeConfig仍只做合并，严格校验在finalizeConfig入口边界完成。自定义说明使用metadata。sampleRate=NaN的valid推导和adcDataColumn=0的最后一列约定保留。

766数值第四参数回归期间发现来源字段toneFrequencySource未列入兼容表，已补登记并通过1600 Hz显式调用验证。DC与十六进制结果的测试路径使用实际返回字段outputFolder，未改变既有返回结构。

## 数值与回归证据

最终数量以[逐测试结果](TEST_RESULTS.csv)为准；该表按同名测试最后一次执行合并，不能理解为一次完整运行的统计。原始运行日志和MAT均在 [验证工作目录](F:/01_Laser/.codex_work/20261002-private-config-optimization)。

| 验证 | 结果 | 证据 |
|---|---|---|
| 原21个配置分支 | 264项共同数值默认值不变 | config_before.mat、config_after.mat、compareDefaults.m |
| 第一轮单元/集成 | 116/116、86/86通过 | unit_results.csv、integration_results.csv |
| 最终针对性回归 | 46/46通过 | acceptance_launch.log、final_targeted_results.csv |
| 特殊配置入口 | 4/4通过 | profile_corrected_launch.log、profile_results.csv |
| 共同增益端到端对照 | 1/1通过；增益1与100均为40 dB，幅值相差100倍 | common_gain_launch.log、common_gain_results.csv |
| 本轮不同测试合并 | 212项，最后一次结果全部通过 | TEST_RESULTS.csv；分批汇总，并非一次全量运行 |
| 干净路径/可迁移检查 | 通过 | acceptance_launch.log、portability_result.mat |
| checkcode | 164文件、37条既有提示；新增代码无提示 | static_final_launch.log、checkcode_final.csv |
| 夹具与重要内核保护 | 14份既有夹具未改，8份关键内核/历史刻度源文件哈希未变 | preserved_kernels.json、源码哈希清单 |
| 文档结构 | 4篇受影响Obsidian笔记当前检查无提示 | documentation_checks.json |

静态检查过程一度因新增测试中多余的警告抑制注释得到43条提示，去除这些注释后复查为37条；没有顺带清理原文件既有提示。

代表性对照使用同一组合成码序列：SFDR/SNR/SINAD/THD/ENOB/CodePp、ADC刻度结果表和DAC幅值拟合，在复制的旧源码和新源码下数值完全一致，见 `numeric_before.mat`、`numeric_after.mat`、`numeric_comparison.log`。这不等于已对每类真实硬件条件验证方法。

特殊配置验证：9726合成9平台，斜率100 µV/code、Vpp=6.5535 V；766合成刻度在默认1525 Hz和显式1600 Hz下均还原100 µV/CodePp。检查了旧签名与保存的最终参数。

中间失败已保留：`final_launch.log`中的零增益用例是预期错误编号写错；`profile_launch.log`中的两项分别为测试读取错误返回字段、toneFrequencySource兼容缺项。后者已修复源码，修正后证据为 `correction_launch.log`、`profile_corrected_launch.log`、`acceptance_launch.log`，没有修改算法以消除失败。

## 刻度来源与未覆盖项

1. 677当前20260928版本系数与公共历史报告系数分别保留。历史运行记录能证明该系数曾被使用，相关路径/哈希见[刻度证据清单](calibration_evidence.csv)。本次未定位到注释所指的20260919原始刻度拟合产物，频率、点数、R²未知字段继续NaN，不把注释数值填写为已验证事实。
2. 677 ILA在100 MHz、131072点时记录1.31072 ms，频点间隔762.939453125 Hz，无法评价1 Hz噪声。PICO覆盖合格也不代表参考面、负载、链路本底或正式条件已确认。
3. 未全面重跑大型历史数据，没有新增硬件/仪器测量；本轮数值证据主要来自现有小型夹具和合成输入。
4. 验证环境为MATLAB R2025b；未启动R2018兼容性实跑，未重新打包独立发布ZIP。干净路径检查支持当前路径独立性，不等同于所有旧MATLAB版本认证。
5. 文件选择与取消主要由现有自动化替身测试覆盖；未人工逐个点击全部GUI入口。
6. 9726直流输出仍采用原CSV/PNG/MAT布局，本轮只增加最终配置记录，未接入统一精简XLSX。
7. 执行成功、数值回归通过、方法已验证、正式满足四种状态分开。此次配置回归不升级任何硬件正式结论。

## 文档与证据文件

- 六器件原README、主README和CONFIGURATION.md已同步。
- Obsidian专题中的02输入参数、06噪声、09使用手册、11后续开发四篇已更新，保留原正文和导航。对本次四篇运行Markdown/双链/表格/Mermaid检查，当前无提示；未宣称全笔记库或浏览器目检通过。
- [配置字段差异](config_diff.csv)、[修改前配置](baseline_configs.json)、[修改后配置](current_configs.json)记录21个原分支；搬入private的新内部profile由源码及新增入口回归补充验证。
- [修改前源码哈希](source_before.csv)、[修改后源码哈希](source_after.csv)、[变化文件哈希](changed_source_hashes.csv)用于核对工作区版本；[静态检查](checkcode_final.csv)保留提示明细。
- 原有Git未提交记忆条目和未跟踪文件保留。项目记忆/审计台账仅追加本轮实证；原始数据、历史结果、黄金夹具未修改。

批处理退出记录：最终46项测试、portability和静态检查完成并写入日志后，验收MATLAB进程未自行退出。核对专用acceptance_launch.log命令行后，仅结束本任务对应的两个残留进程；未以进程退出码代替测试断言结果。详情见验证目录completed_batch_cleanup.json。其余共同增益及最终静态复查进程正常退出。
