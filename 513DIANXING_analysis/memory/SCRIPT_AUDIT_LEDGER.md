# CW_513_ANALYSIS 脚本方法审计台账

## 2026-09-17 ADC128带宽入口

新增128_hy独立入口和12 bit unsigned配置，共用2208带宽内核。采样率未知时要求用户填写，不默认100 MHz。原始码只减2048，正弦拟合保留DC；近轨、R²和频率一致性筛选后计算相对幅值与−3 dB交点。MATLAB R2025b合成7频点端到端通过，交点约2684.5 Hz与独立插值一致，DC平移不改变CodePp，超Nyquist输入在创建输出前拒绝，3个生产文件checkcode为0项。验证脚本：`F:/01_Laser/.codex_work/20260917-adc128-bandwidth/verify_adc128.m`。未提供实测数据，未验证实际CSV列、时基及板端条件；方法状态不升级为实测已验证。

- 建立日期：2026-08-31
- 审计范围：五个正式器件目录、`_shared/+converter`、日常测试和发布工具
- 排除：`_release`、`legacy`、`Matlab_AND_ExampleData_lyp`、`_templates` 和外部旧 workflow

## 2026-09-09 AD9245 ILA时基说明更正

AD9245旧ILA数据为25 MHz（40 ns），后续计划改为20 MHz（50 ns）。只有实际用20 MHz采集的新数据才按20 MHz分析，旧数据仍用25 MHz，不要在同一次运行中混用两种时基的文件。

当前MATLAB的 `9245_hy/private/ad9245Config.m` 仍设置 `ilaCaptureSampleRateHz=25e6`，SFDR、带宽、隔离度、功率刻度和INL/DNL的 `config.sampleRate` 均取这个值。`adcConversionClockHz=20e6` 表示ADC转换时钟，不能代替旧CSV的ILA时基。本次只修正文档，脚本默认值未改，也未核验后续FPGA时钟修改是否已完成。

此前文档将旧ILA时基写为20 MHz有误，现已更正。`METRICS.md` 还按当前代码更正了隔离度默认频率10 kHz、刻度默认频率1 kHz和自动识别数据列。本次未重算旧结果，测试和测量结论不变。

## 状态定义

### 2026-09-09 用户指定取消码端余量

AD2208/AD9245的inl_dnl配置marginCode从1000改为0，取消额外向内裁剪。同步两份器件README、METRICS、核心测试配置和黄金基线适用性说明；不修改核心概率公式、近轨/毛刺/拟合门槛或历史数值。原方法审查中的通道与统计覆盖问题未修复。验证日志：F:/01_Laser/.codex_work/20260909-inl-dnl-review/margin_zero_tests.log。无原始数据重算，不发布私人记忆。

### 2026-09-09 INL/DNL 定向方法审查

本次仅审查AD2208/AD9245共用INL/DNL链，未修改算法、配置、原始数据或GitHub。方法状态保持“审计中”，不能升级为已验证。

- 实现：readAdcCsv码型转换；逐记录FFT/频率优化与正弦最小二乘；R²/毛刺/近轨筛选；各记录公共幅值区间去除1000码端余量；分记录条件概率加权混合；DNL=实测/理论概率−1；INL=cumsum(DNL)减全分析区间的一阶最小二乘直线。它是部分码域best-fit结果，不是全量程endpoint INL。不使用电压刻度。
- P1：runInlDnl只按第一文件完整路径命名通道，不校验各文件表头，不阻止混合接口。
- P1：CoverageRatio仅输出，不参与状态门槛；没有每码最少命中、相位覆盖或不确定度检查。131072点理想14位ADC、幅度7000码、固定16相位的合成数据：R²=0.9999999976、覆盖0.00100008、DNL最大1180.164 LSB、INL最大1103.354 LSB，仍Status=OK（FormalConclusion仍为暂不能判定）。
- 对照：相位充分铺开的131072点理想量化正弦，覆盖1，最大DNL=0.164939 LSB、INL=0.0862653 LSB。有限采样估计不等于理论ADC真值。
- 对照：同一码序列仅把fs从25MHz改为20MHz，频率变为0.8倍，DNL最大差2.06e-12、INL最大差3.33e-12。采集重复/缺失和CDC问题不能通过改fs修复。
- P2：非有限码值直接剔除后压缩时间索引；自动数据列实为末列；十六进制基数依赖解析失败回退；部分码域和best-fit定义未在图标题明确。R²不能替代输入源失真、时钟/valid和统计覆盖证据。
- 验证：本机MATLAB R2025b，6个目标函数checkcode均0条提示；纯计算核心依赖检查仅MATLAB。无可用MATLAB MCP静态分析工具/编码规范资源，使用本机checkcode及人工核验。现有INL测试多验证流程、筛选和输出存在，未证明已知非线性恢复精度。本次没有重跑完整120项或全部真实INL数据。
- 证据目录：F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/inl_dnl_review_20260909，含review_checks.m、review_checks.log、review_checks.mat和synthetic_summary.csv。参考ADI Histogram Testing Determines DNL and INL Errors及INL/DNL Measurements for High-Speed ADCs。

- `待方法审计`：文件存在，但公式、单位、参考面、数据选择和独立复算尚未全部核对。
- `审计中`：已开始逐行/逐公式检查，尚有问题或证据待补。
- `有条件可用`：方法的主要检查已完成，但需求、参考面、覆盖或真实数据仍有限制。
- `已验证`：实现、文档、独立复算、测试和代表性真实数据回归全部一致。
- `禁用`：发现会导致错误结果或误判的问题，在修复前不得作为正式入口。

“存在测试证据”单独记录，不能替代方法状态。初始方法状态统一为“待方法审计”。

## 审计记录必填字段

每次更新一行时至少记录：

1. 输入格式、采样率、码型、数据列、通道和采集条件；
2. 公式、单位、窗函数/拟合模型、归一化和参考面；
3. 有效点、排除点、削顶、毛刺、覆盖和异常处理；
4. 需求来源、限值和正式结论开关；
5. 输出 CSV/MAT/图片/状态/哈希；
6. 独立复算方法、测试名称、黄金数据和审计日期；
7. 发现的问题、修复提交或批准依据。

## 器件入口、配置、批处理与审计

以下表格保留初次审计时的文件和问题，包括后来归档的脚本。删除、修复及新增测试记录见文末各日期条目；不要把表格中的历史文件当作当前入口。

| 器件 | 脚本 | 指标/责任 | 公共核心或关键依赖 | 当前测试证据 | 方法状态 | 待核对重点 |
|---|---|---|---|---|---|---|
| AD2208 | `2208_hy/adc_sfdr_analysis.m` | SFDR/SNR/SINAD/THD/ENOB | `converter.adc.runSfdr` | `adcCoreTest` 部分覆盖 | 待方法审计 | 100 MHz、FFT/窗/基波谐波掩码、单边谱和单位 |
| AD2208 | `2208_hy/adc_bandwidth_analysis.m` | 输入频率响应和带宽 | `converter.adc.runBandwidth` | `adcCoreTest` 部分覆盖 | 待方法审计 | 文件频率解析、正弦拟合、低频参考、交点与覆盖 |
| AD2208 | `2208_hy/adc_isolation_analysis.m` | 通道隔离度 | `converter.adc.runIsolation` | `adcCoreTest` 部分覆盖 | 待方法审计 | 驱动/受扰配对、参考幅度、频率和 40 dB 限值来源 |
| AD2208 | `2208_hy/adc_power_scale_analysis.m` | `CodePp -> Vpp` 刻度及99%临界输入 | `converter.adc.runPowerScale`、`estimateCriticalInput` | `adcCoreTest`、`criticalInputEstimateTest`、`ad2208PowerScaleWorkflowTest` | 待方法审计 | dBm→Vpp 阻抗、正弦拟合、98%削顶筛选、正负轨99%临界拟合、夹逼范围和反向式 |
| AD2208 | `2208_hy/adc_inl_dnl_analysis.m` | 正弦码密度 INL/DNL | `converter.adc.runInlDnl` | `adcCoreTest` 部分覆盖 | 待方法审计 | 多记录独立性、概率模型、码端余量、有效记录比例和 R² |
| AD2208 | `2208_hy/adc_ila_noise_analysis.m` | ADC 输入等效噪声 | `converter.adc.runInputNoise` | `adcCoreTest` 部分覆盖 | 待方法审计 | 码到电压刻度、Welch/PSD、10–25 MHz 频带和 300 nV/√Hz 来源 |
| AD2208 | `2208_hy/run_ad2208_batch.m` | 自动分组批处理 | 上述入口 | 无独立集成基线 | 待方法审计 | 数据树、文件选择、重复数据、错误隔离和汇总状态 |
| AD2208 | `2208_hy/run_ad2208_isolation_batch.m` | 隔离度配对批处理 | `adc_isolation_analysis` | 无独立集成基线 | 待方法审计 | 文件名配对、20 组矩阵、缺失/重复配对 |
| AD2208 | `2208_hy/ad2208_build_input_coverage.m` | 输入覆盖与哈希清单 | runtime SHA-256 | 无独立测试 | 待方法审计 | 文件范围、哈希、重复文件和结果目录排除 |
| AD2208 | `2208_hy/audit_ad2208_results.m` | 结果包审计 | runtime/清单 | 无独立测试 | 待方法审计 | 必需文件、输入哈希、失败状态和过期结果识别 |
| AD2208 | `2208_hy/private/ad2208Config.m` | 16 bit/100 MHz/第4列及限值 | `converter.runtime.validateConfig` | 间接受单元测试覆盖 | 待方法审计 | 每个指标的采样率、阈值、数据列和需求版本 |
| AD2208 | `2208_hy/private/bootstrapRuntime.m` | 运行内核解析 | `internal` 或 `_shared` | `portabilityTest` 间接覆盖 | 待方法审计 | 禁止旧 workflow 回退、路径污染和函数缓存 |
| AD9245 | `9245_hy/adc_sfdr_analysis.m` | 动态指标 | `converter.adc.runSfdr` | 集成测试已补充；2026-09-15 MATLAB启动失败，未运行 | 待方法审计 | 旧25 MHz ILA按1:5:end抽样并以5 MHz分析；周期Hann窗；旧数据仅作估算；掩码与黄金来源仍待审计 |
| AD9245 | `9245_hy/adc_bandwidth_analysis.m` | 输入频率响应和带宽 | `converter.adc.runBandwidth` | AD9245 集成测试和黄金 CSV | 待方法审计 | 实际采样率覆盖、参考点和无 −3 dB 交点处理 |
| AD9245 | `9245_hy/adc_isolation_analysis.m` | 通道隔离度 | `converter.adc.runIsolation` | AD9245 集成测试和黄金 CSV | 待方法审计 | 驱动端、受扰端、频率、参考面和矩阵完整性 |
| AD9245 | `9245_hy/adc_power_scale_analysis.m` | `CodePp -> Vpp` 刻度及99%临界输入 | `converter.adc.runPowerScale`、`estimateCriticalInput` | AD9245 集成测试、`criticalInputEstimateTest`和黄金 CSV | 待方法审计 | dBm→Vpp、50 Ω条件、拟合方向、98%削顶筛选和正负轨99%夹逼拟合 |
| AD9245 | `9245_hy/adc_inl_dnl_analysis.m` | 正弦码密度 INL/DNL | `converter.adc.runInlDnl` | AD9245 集成测试和黄金 CSV | 待方法审计 | 码密度理论、拟合 R²、异常毛刺和巨大 INL 的真实性 |
| AD9245 | `9245_hy/adc_input_noise_analysis.m` | AD9245→FPGA G=128→DA9726 JG18 1 Hz 输入等效噪声 | `noise_chain_hy/adc_input_equiv_noise_analysis` | X3G/X4G 20 s Pico MAT 真实数据验证 | 待方法审计 | ADC/JG18 刻度来源、Pico 参考面、总链路本底、1 Hz 估计方差、X1G/X2G 截断记录 |
| AD9245 | `9245_hy/private/ad9245Config.m` | 14 bit/采样率/数据列及限值 | `converter.runtime.validateConfig` | AD9245 集成测试 | 待方法审计 | 指标实际采样率、默认列识别和限值来源 |
| AD9245 | `9245_hy/private/bootstrapRuntime.m` | 运行内核解析 | `internal` 或 `_shared` | `portabilityTest` 间接覆盖 | 待方法审计 | 独立包与开发库数值一致性 |
| AD677 | `677_hy/adc_bandwidth_analysis.m` | 输入频率响应 | `converter.adc.runBandwidth` | `ad677ContractTest`、`ad677WorkflowTest` | 待方法审计 | 100 MHz ILA 保持码、valid 脉冲、实际转换率和覆盖 |
| AD677 | `677_hy/adc_power_scale_analysis.m` | `CodePp -> Vpp` 刻度及99%临界输入外推 | `converter.adc.runPowerScale`、`estimateCriticalInput` | `ad677ContractTest`、`ad677WorkflowTest`、`criticalInputEstimateTest` | 待方法审计 | High-Z 显示 Vpp、板端参考面、setpoint manifest、98%削顶筛选和无夹逼外推标记 |
| AD677 | `677_hy/adc_ila_noise_analysis.m` | 100 MHz ILA全记录点输入等效PSD/ASD | `converter.adc.runInputNoise` | `ad677WorkflowTest`已编写；2026-09-14 MATLAB启动失败，未运行 | 待方法审计 | 固定677斜率、保持码影响、valid更新率、1 Hz～10 kHz频带与无正式限值 |
| 公共绘图 | `_shared/+converter/+report/plotSpectrum.m` | 噪声频带标线 | ASD/PSD绘图入口 | 2026-09-14静态检查；MATLAB启动失败，未运行 | 已修正显示单位 | 频率按Hz/kHz/MHz自适应，10 kHz不再被格式化为0 MHz |
| AD677 | `677_hy/adc_pico_noise_1hz_analysis.m` | AD677→FPGA G=128→DA9726 JG18的1 Hz输入等效噪声 | `noise_chain_hy/adc_input_equiv_noise_analysis` | `ad677WorkflowTest`和文件选择测试已编写；2026-09-14 MATLAB启动失败，未运行 | 待方法审计 | MAT时基、接口显式选择、固定ADC/JG18斜率、至少5秒记录与总链路本底 |
| AD677 | `677_hy/run_ad677_batch.m` | 两通道批处理 | 上述两个入口 | `ad677WorkflowTest` | 待方法审计 | 输入发现、通道映射、raw/results 同级约定和状态汇总 |
| AD677 | `677_hy/audit_ad677_results.m` | 结果包审计 | runtime/清单 | `ad677WorkflowTest` 间接覆盖 | 待方法审计 | 哈希、必需文件、正式状态关闭和过期结果 |
| AD677 | `677_hy/private/ad677Config.m` | 16 bit/100 MHz ILA/第4列/valid第5列 | `converter.runtime.validateConfig` | `ad677ContractTest` | 待方法审计 | ILA 时钟与 ADC 有效样本率的区别 |
| AD677 | `677_hy/private/ad677PowerSetpoints.m` | Vpp 测试点清单 | manifest/文件名 | `ad677ContractTest` 部分覆盖 | 待方法审计 | 每个 setpoint 的来源、单位和 error 文件处理 |
| AD677 | `677_hy/private/ad677ResolveInputs.m` | 数据输入解析 | `converter.io` | `ad677ContractTest` 部分覆盖 | 待方法审计 | 通道/文件选择、重复文件、manifest 一致性 |
| AD677 | `677_hy/private/bootstrapRuntime.m` | 运行内核解析 | `internal` 或 `_shared` | `portabilityTest` 间接覆盖 | 待方法审计 | 独立包优先级和路径清理 |
| DA9726 | `9726_hy/dac_scale_analysis.m` | DAC 码值—Vpp 刻度 | `converter.dac.runScale` | `dacCoreTest` 部分覆盖 | 待方法审计 | Pico 通道、文件名 code、正弦拟合方向和排除点 |
| DA9726 | `9726_hy/dac_noise_analysis.m` | ASD 和积分噪声 | `converter.dac.runNoise` | `dacCoreTest` 部分覆盖 | 待方法审计 | 250 kS/s、0.2 Hz、最少4段、ASD-only、增益/参考面 |
| DA9726 | `9726_hy/dac_isolation_analysis.m` | DAC 隔离度 | `converter.dac.runIsolation` | `dacCoreTest` 部分覆盖 | 待方法审计 | pair manifest、驱动/受扰、采集通道、参考幅度和 40 dB |
| DA9726 | `9726_hy/run_da9726_batch.m` | DAC 批处理 | 三个 DAC 入口 | 无真实数据集成基线 | 待方法审计 | 缺项处理、scaleFolder/pairManifest 和状态汇总 |
| DA9726 | `9726_hy/audit_da9726_results.m` | 结果包审计 | runtime/清单 | 无独立测试 | 待方法审计 | 正式结论关闭、必需字段、哈希和失败包 |
| DA9726 | `9726_hy/private/da9726Config.m` | 采样、Welch、限值和正式开关 | `converter.runtime.validateConfig` | `dacCoreTest` 间接覆盖 | 待方法审计 | 需求来源、负载、量程、增益和正式开关 |
| DA9726 | `9726_hy/private/bootstrapRuntime.m` | 运行内核解析 | `internal` 或 `_shared` | `portabilityTest` 间接覆盖 | 待方法审计 | 开发/发布内核一致性 |
| DA766 | `766_hy/dac_scale_analysis.m` | DAC 码值—Vpp 刻度 | `converter.dac.runScale` | `dacCoreTest` 部分覆盖 | 待方法审计 | 器件范围、文件名 code、采样条件和参考面 |
| DA766 | `766_hy/dac_scale_hex_analysis.m` | DA766 无符号16进制码值适配单通道刻度 | `dac_scale_analysis` -> `converter.dac.runScale` | `dacCoreTest/hexUnsignedCodeNamesAreSignExtended`；2026-08-26 真实数据；本次重算纳入 0x7FFF | 待方法审计 | `CODExxxx`/`CODExxxx-0002` 解析、有符号补码、1525 Hz 证据、8点拟合、参考面 |
| DA766 | `766_hy/run_da766_scale_hex_batch.m` | DA766 06_scale 八通道批处理、逐接口图与选择清单 | `dac_scale_hex_analysis`、runtime/report | 8通道×8文件；本次重算每通道独立 PNG/FIG；runtime audit 8/8通过 | 待方法审计 | CH2历史文件排除、0x7FFF全量拟合、k/b科学计数法、输入 SHA-256、正式开关关闭 |
| DA766 | `766_hy/dac_noise_analysis.m` | ASD 和积分噪声 | `converter.dac.runNoise` | `dacCoreTest` 部分覆盖 | 待方法审计 | 分辨率重算、40 dB 放大器回退、Pico 底噪和需求冲突 |
| DA766 | `766_hy/dac_isolation_analysis.m` | DAC 隔离度 | `converter.dac.runIsolation` | `dacCoreTest` 部分覆盖 | 待方法审计 | 20 kHz/实际频率、配对清单、参考幅度和端口映射 |
| DA766 | `766_hy/run_da766_batch.m` | DAC 批处理 | 三个 DAC 入口 | 无真实数据集成基线 | 待方法审计 | 数据目录命名、缺项、批次隔离和汇总 |
| DA766 | `766_hy/audit_da766_results.m` | 结果包审计 | runtime/清单 | 无独立测试 | 待方法审计 | 需求冲突、正式开关、哈希和失败包 |
| DA766 | `766_hy/private/da766Config.m` | 采样、Welch、限值和正式开关 | `converter.runtime.validateConfig` | `dacCoreTest` 间接覆盖 | 待方法审计 | 需求版本、接口别名、放大器增益和参考面 |
| DA766 | `766_hy/private/bootstrapRuntime.m` | 运行内核解析 | `internal` 或 `_shared` | `portabilityTest` 间接覆盖 | 待方法审计 | 开发/发布内核一致性 |

## ADC 公共计算

| 脚本 | 责任 | 当前测试证据 | 方法状态 | 待核对重点 |
|---|---|---|---|---|
| `_shared/+converter/+adc/analyzeDynamicMetrics.m` | 频谱动态指标汇总 | `adcCoreTest` | 待方法审计 | 功率求和、基波/谐波/DC 掩码、噪声定义和 dB 单位 |
| `calculateBandwidth.m` | 相对响应和 −3 dB 交点 | `adcCoreTest` | 待方法审计 | 参考值、对数频率插值、无交点和多交点 |
| `calculateInlDnl.m` | 正弦码密度 DNL/INL | `adcCoreTest` | 待方法审计 | 理论概率、端点/最佳拟合定义、缺码和累计方式 |
| `calculateIsolation.m` | 驱动/受扰幅度比 | `adcCoreTest` | 待方法审计 | 20log10、零幅值、防除零、最差值定义 |
| `calculatePowerScale.m`、`estimateCriticalInput.m` | `CodePp -> Vpp` 线性拟合及正负轨99%临界输入估计 | `adcCoreTest`、`criticalInputEstimateTest` | 待方法审计 | 拟合方向、有效范围、98%筛选与99%目标独立性、限制轨、夹逼/外推状态、残差和R² |
| `codePpToInputPowerDbm.m` | 由刻度反算等效 dBm | `adcCoreTest` 部分覆盖 | 待方法审计 | 只能作为明确阻抗下的派生量，不能取代正式 Vpp 刻度 |
| `dbmToVpp.m` | dBm→Vpp | `adcCoreTest` 部分覆盖 | 待方法审计 | RMS/峰峰值公式、阻抗、标量/向量和非法输入 |
| `estimateFrequency.m` | 初始频率估计 | `adcCoreTest` 部分覆盖 | 待方法审计 | DC 去除、窗、频率栅格、低频和近 Nyquist |
| `findAccuratePeak.m` | 频谱峰值细化 | `adcCoreTest` 部分覆盖 | 待方法审计 | 插值模型、边界 bin 和幅值修正 |
| `findThreeDbCrossing.m` | −3 dB 交点搜索 | `adcCoreTest` 部分覆盖 | 待方法审计 | 单调假设、覆盖不足和插值域 |
| `fitSine.m` | 正弦拟合 | `adcCoreTest` | 待方法审计 | 频率固定/自由、偏置、幅值、相位、R²和残差 |
| `refineSineFrequency.m` | 正弦频率精细化 | `adcCoreTest` 部分覆盖 | 待方法审计 | 搜索范围、局部极值、样本时基和收敛失败 |
| `runBandwidth.m` | 带宽分析流程 | `adcCoreTest`、AD9245/AD677 集成测试 | 待方法审计 | IO→拟合→归一化→交点→状态的完整一致性 |
| `runInlDnl.m` | INL/DNL 分析流程 | `adcCoreTest`、AD9245 集成测试 | 待方法审计 | 多记录合并、有效比例、异常记录和输出字段 |
| `runInputNoise.m` | ADC 输入等效噪声分析流程 | `adcCoreTest` 部分覆盖 | 待方法审计 | 码值标定、PSD/ASD、积分和参考面 |
| `runIsolation.m` | ADC 隔离度分析流程 | `adcCoreTest`、AD9245 集成测试 | 待方法审计 | 配对、通道识别、参考幅度和矩阵/最差值 |
| `runPowerScale.m` | ADC 刻度分析流程 | `adcCoreTest`、AD9245/AD677 集成测试 | 待方法审计 | setpoint 来源、有效点、正式字段和图表一致性 |
| `runSfdr.m` | SFDR 分析流程 | `adcCoreTest`、AD9245 集成测试 | 待方法审计 | FFT 归一化、指标口径、文件频率和失败条件 |
| `vppToDbm.m` | Vpp→dBm 派生换算 | `adcCoreTest` 部分覆盖 | 待方法审计 | 明确阻抗、反函数一致性和高阻数据标记 |

## DAC 公共计算

| 脚本 | 责任 | 当前测试证据 | 方法状态 | 待核对重点 |
|---|---|---|---|---|
| `_shared/+converter/+dac/fitTone.m` | DAC/Pico 正弦拟合 | `dacCoreTest` | 待方法审计 | 时基、偏置、幅值/Vpp、频率和拟合质量 |
| `loadPicoMat.m` | DAC 层 Pico MAT 兼容入口 | `dacCoreTest` 部分覆盖 | 待方法审计 | 与 `converter.io.loadPicoMat` 的唯一实现关系、通道/单位 |
| `runScale.m` | DAC 刻度分析流程 | `dacCoreTest` | 待方法审计 | Code/Vpp 方向、文件名解析、排除点和 R² |
| `runNoise.m` | Welch PSD/ASD 与积分噪声 | `dacCoreTest` | 待方法审计 | 窗功率归一化、单边谱、分段/重叠、积分频带、增益回退 |
| `runIsolation.m` | DAC 隔离度分析流程 | `dacCoreTest` | 待方法审计 | pair manifest、参考音调、幅度比、通道/频率和状态 |

## IO 公共函数

| 脚本 | 责任 | 当前测试证据 | 方法状态 | 待核对重点 |
|---|---|---|---|---|
| `_shared/+converter/+io/detectChannel.m` | 自动通道识别 | `ioUtilitiesTest` | 待方法审计 | 表头/文件名冲突、模糊匹配和未知通道 |
| `extractChannel.m` | 提取指定 ADC 通道 | `ioUtilitiesTest` | 待方法审计 | 列类型、缺失列、valid 掩码和数值转换 |
| `loadPicoMat.m` | Pico MAT 变量和通道加载 | `ioUtilitiesTest`、`dacCoreTest` | 待方法审计 | 不同 Pico 保存结构、采样间隔、单位和通道选择 |
| `parseDrivenChannel.m` | 解析隔离度驱动端 | `ioUtilitiesTest` | 待方法审计 | 命名变体、歧义和失败策略 |
| `parseFrequencyHz.m` | 文件名频率解析 | `ioUtilitiesTest` | 待方法审计 | Hz/kHz/MHz、mHz、负号和误匹配 |
| `parsePowerDbm.m` | 文件名 dBm 解析 | `ioUtilitiesTest` | 待方法审计 | N10/−10/小数/大小写和非功率数字 |
| `readAdcCsv.m` | Vivado/ADC CSV 读取 | `ioUtilitiesTest` | 待方法审计 | 表头行、十六/十进制、有符号补码、数据列和 NaN |
| `resolveOutputBase.m` | 默认 `results` 目录 | `ioUtilitiesTest` | 待方法审计 | raw 同级、显式输出、目录大小写和只读输入 |
| `selectCsvFiles.m` | 显式/交互 CSV 选择 | `ioUtilitiesTest` 部分覆盖 | 待方法审计 | 取消、排序、重复文件和非交互运行 |

## 报告、绘图和运行时

| 分组 | 脚本 | 责任 | 当前测试证据 | 方法状态 | 待核对重点 |
|---|---|---|---|---|---|
| report | `plotBandwidth.m` | 频响/带宽图 | 集成测试间接覆盖 | 待方法审计 | 坐标/单位、参考线、覆盖不足和白底 |
| report | `plotInlDnl.m` | INL/DNL 图 | 集成测试间接覆盖 | 待方法审计 | INL/DNL 定义、异常点、限值和白底 |
| report | `plotIsolation.m` | 隔离度图 | 集成测试间接覆盖 | 待方法审计 | 驱动/受扰标签、阈值、矩阵和白底 |
| report | `plotPowerScale.m` | `CodePp -> Vpp` 刻度图 | 集成测试间接覆盖 | 待方法审计 | 轴方向、有效/排除点、公式、残差和白底 |
| report | `plotSfdrSpectrum.m` | 单文件频谱图 | 集成测试间接覆盖 | 待方法审计 | dBFS/功率口径、标注、频率轴和白底 |
| report | `plotSfdrSummary.m` | SFDR 汇总图 | 集成测试间接覆盖 | 待方法审计 | 聚合方式、单位、限值和白底 |
| report | `plotSpectrum.m` | ASD/PSD 通用谱图 | `dacCoreTest` 间接覆盖 | 待方法审计 | 单位、参考面、1 Hz 横线、无意义竖线和白底 |
| report | `saveFigure.m` | PNG/FIG 统一导出 | `portabilityTest` 间接覆盖 | 待方法审计 | Figure/Axes 白底、黑字、渲染器、分辨率和关闭行为 |
| report | `writeTable.m` | CSV/表格输出 | 单元测试间接覆盖 | 待方法审计 | 编码、字段顺序、NaN/Inf 和 R2018 兼容 |
| runtime | `applyRunOptions.m` | 可选运行参数覆盖 | `ad677ContractTest` 间接覆盖 | 待方法审计 | 白名单、类型、默认不变和未知字段 |
| runtime | `auditRun.m` | 结果包完整性审计 | 集成测试间接覆盖 | 待方法审计 | 必需文件、哈希、状态冲突和过期输入 |
| runtime | `createRun.m` | 时间戳运行目录和初始日志 | 集成测试间接覆盖 | 待方法审计 | 同秒冲突、失败清理和输出边界 |
| runtime | `finishRun.m` | 成功/失败状态收尾 | 集成测试间接覆盖 | 待方法审计 | 异常路径、状态互斥、日志和未完成运行 |
| runtime | `getGitRevision.m` | Git 修订信息 | `portabilityTest` 间接覆盖 | 待方法审计 | 非 Git/unsafe repository 时的可追溯降级 |
| runtime | `mergeConfig.m` | 配置合并 | 单元测试间接覆盖 | 待方法审计 | 深/浅合并、未知字段和器件固定参数保护 |
| runtime | `sha256File.m` | 文件 SHA-256 | `ioUtilitiesTest` 间接覆盖 | 待方法审计 | 大文件、二进制读取、大小写和失败处理 |
| runtime | `validateConfig.m` | 配置完整性检查 | `adcCoreTest`/`dacCoreTest` 间接覆盖 | 待方法审计 | 每指标必需字段、单位、范围和正式开关 |
| runtime | `valueToText.m` | 参数序列化 | 单元测试间接覆盖 | 待方法审计 | struct/cell/string/NaN、稳定顺序和可读性 |
| runtime | `writeRunManifest.m` | 参数、输入和运行清单 | 集成测试间接覆盖 | 待方法审计 | 源路径、哈希、工具箱、Git 版本和参考条件 |

## 测试与发布工具

| 脚本 | 责任 | 方法状态 | 待核对重点 |
|---|---|---|---|
| `tests/run_all_tests.m` | 执行全部测试 | 待方法审计 | 失败传播、测试根、环境隔离和结果摘要 |
| `tests/run_golden_regression.m` | 黄金回归 | 待方法审计 | 容差、黄金来源、禁止静默更新和字段覆盖 |
| `tests/run_portability_smoke.m` | 迁移冒烟测试 | 待方法审计 | 移除旧路径、clear functions、依赖边界和五器件覆盖 |
| `tools/buildDeviceRelease.m` | 构建独立器件包 | 待方法审计 | 注册表、内核复制、版本、SHA256SUMS 和排除历史文件 |
| `tools/deviceReleaseRegistry.m` | 发布器件注册 | 待方法审计 | 五器件入口、releaseReady/formalEnabled 和版本 |
| `tools/verifyDeviceRelease.m` | 独立包验证 | 待方法审计 | 源码路径隔离、requiredFilesAndProducts 和合成冒烟 |
| `tools/run_cw513_ad_input_analysis_20260819.m` | 特定批次 AD 输入分析 | 待方法审计 | 批次路径、临时覆盖、可重复性和是否仍需保留 |
| `tools/run_cw513_ad2208_new_data_20260820.m` | 特定批次 AD2208 分析 | 待方法审计 | 数据选择、输出目录、硬编码条件和结果追溯 |
| `tools/run_cw513_ad9245_analysis_20260820.m` | 特定批次 AD9245 分析 | 待方法审计 | 数据选择、输出目录、硬编码条件和结果追溯 |

## 关联分析入口

| 脚本 | 定位 | 方法状态 | 待核对重点 |
|---|---|---|---|
| `noise_chain_hy/adc_input_equiv_noise_analysis.m` | 五器件主入口之外的 ADC 输入等效噪声/链路分析 | 待方法审计 | 刻度来源、链路增益、各噪声参考面、PSD 分离方法及是否应并入正式入口 |

## 推荐审计顺序

1. `converter.io`、器件配置、码型和采样率。
2. `converter.runtime` 的证据包、哈希和状态。
3. ADC SFDR → 带宽 → 隔离度 → 刻度 → INL/DNL → 输入噪声。
4. DAC 刻度 → 噪声 → 隔离度。
5. 绘图、单位、阈值和参考面。
6. 器件包装器、批处理、结果审计和独立发布。
7. 真实数据独立复算与黄金基线批准。

每完成一项，在对应行补充审计日期、审计人/任务、证据路径、发现问题、修复版本和最终状态。

## 2026-09-08 日常路径清理

已将历史 legacy 区、_release 生成发布副本、三个固定日期批次驱动和未被正式 CodePp→Vpp 流程引用的 codePpToInputPowerDbm.m 移入 F:\01_Laser\research_assets\CW_513_ANALYSIS_archive\20260908。它们不再进入日常 MATLAB 路径。converter.dac.loadPicoMat.m 因 tests/unit/dacCoreTest.m 直接调用而保留，noise_chain_hy 作为当前 PICO 联合噪声链保留。逐文件 SHA-256、恢复说明和清理前后状态见归档目录 CLEANUP_RECORD.md、cleanup_manifest.csv 及本次 .codex_work/20260908-cw513-cleanup。


## 2026-09-08 当前磁盘全面审计（script_audit_20260908_202429）

本节记录当时的只读审计结果，原结论保留。单元测试通过不表示算法已经完成方法验证。

- 证据与可读报告：[script_audit_20260908_202429](<F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/script_audit_20260908_202429/AUDIT_REPORT.md>)；全量脚本矩阵：[script_matrix.csv](<F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/script_audit_20260908_202429/script_matrix.csv>)；逐入口命令：[entry_commands.md](<F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/script_audit_20260908_202429/entry_commands.md>)。
- 当前盘点272个.m、33个正式分析/批处理/审计入口；checkcode全覆盖；已有52项测试全通过。独立方法探针6项：1通过、5失败。真实数据主运行87项：75成功、12失败；补充19项：16成功、3失败。
- ADC刻度14组表间算术和14份原始CSV最小二乘复算通过；40dB增益/单边Welch数值探针通过。仅验证对应实现和声明时基，不确认板端量程、时钟或参考面。
- SFDR/THD：待修复与方法验证（F01/F08）。ADC/DAC隔离：待方法验证，频率/有效性门控缺失（F02/F03）；DA766已按驱动目录建立56对诊断，20kHz名义频率与实际约19.836kHz不符。DA9726的1MHz/250kS/s条件不支持直接正式结论。
- AD2208批处理/审计/隔离批处理：失败（F05/F15/F16）；AD677四组批处理：执行及结构审计通过，方法参考面仍有限制。DAC通用batch：空输出参数失败（F10）；现有通用刻度命名不适配（F11）；DA766专用hex批处理8通道执行成功。
- 噪声入口：AD2208绝对文件路径补跑通过；AD9245/noise_chain执行成功不代表每条数据有效，存在路径污染和默认数据名问题（F04/F12）。原始MAT读取失败单独记录。
- 95个SUCCESS结果包中74通过结构审计、21失败（18缺参数CSV、2缺manifest、1缺result MAT）；输入哈希均一致。结果审计不能代表方法通过（F13/F18）。黄金回归因旧数据目录缺失未进入数值比较。
- 18项发现含具体文件行号、复现条件、影响、建议，见findings.csv。修复版本：无（未修改既有源码/配置/基线）。272源码、1203输入SHA-256前后一致；原Git修改保留，未提交/推送。

## 2026-09-08 2208单项噪声入口和四份README

此次修改包括入口改名、新增调用入口和补充文档；数值公式、器件配置、动态范围和黄金基线未改。

| 指标链 | 本次实现/输入 | 测试证据 | 方法状态 |
|---|---|---|---|
| AD2208直接ILA | adc_ila_noise_analysis；100MHz/16bit/signed/第4列；JG15/JG17/JG22原CSV；原外部输入刻度、10–25MHz、Welch和全记录谱 | 改名前后数值一致、输入哈希一致 | 方法状态不变，原有限制仍适用 |
| AD2208 PICO 1Hz | adc_pico_noise_1hz_analysis→noise_chain；JG24 A/Tinterval、G128；ADC工作簿+DA9726 JG18斜率；不扣本底、正式未测试 | 10/10入口测试；PSD和ASD核心比较通过；包结构PASS；源码/数据哈希；白底图抽查 | 入口测试通过；参考面、本底和硬件条件仍待确认 |
| 四目录README | 7/6/3/4共20入口；当前参数/覆盖/数据/输出 | 源码逐项核对；20入口checkcode无提示；已有52项测试通过 | 已核对文档，未完成20项方法的全部验证 |

证据：[noise_entry_readme_20260908_223458/VERIFICATION_REPORT.md](<F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/noise_entry_readme_20260908_223458/VERIFICATION_REPORT.md>)。
未覆盖：其它PICO接口、人工桌面交互、其它18入口全部真实数据重跑。取消分支用UI返回桩验证。无修复提交或推送。

## 2026-09-08 AD2208 PICO固定DA9726刻度

DA9726 JG18斜率固定为1.01451391294771e-4 V/CodePp。2208入口版本1.1.0，取消DAC文件查找和读取；ADC工作簿仍读取。MATLAB三项检查通过，包括无DA9726目录的隔离真实JG24运行；ASD与固定前一致，结果记录了固定系数来源，不再记录DAC文件哈希。仍不扣本底，正式状态为“未测试”。证据：F:\01_Laser\0_20260727_513test\CW_Data\513_CW_DATA\results\fixed_dac_20260908_231657\VERIFICATION.md。

## 2026-09-08 单项文件选择、文档同步和完整库发布

- 四器件20项及677两项入口改为选择具体文件，不再使用固定列表或默认扫描全目录。显式调用不弹窗，取消不生成结果，并检查输入路径和重名；DAC配对需填写参考面和接口。DAC空输出目录支持和2208隔离配置按字段覆盖已修复；历史审计中尚未解决的方法问题继续保留。
- ILA2208采用单段Hann、0重叠、131072点固定NFFT，并拒绝不匹配长度。这项配置与旧100段平均不同，结果不能按同一处理条件比较。PICO两器件固定DAC系数保持各自数值，未混用。
- 120/120自动化、4/4真实数据回归、3/3固定DAC检查通过；最后目录末尾分隔符规范化定向断言通过。原始实测输入哈希一致。交互测试使用UI桩模拟，未做人工界面操作或新硬件测量，方法状态和正式判据不变。
- 四份README_先看、主README、ARCHITECTURE、METRICS、677说明及PROJECT_MEMORY同步。完整库发布到513_CW_MATLAB；不提交原始实测数据、历史归档及父仓库无关修改。
- 证据：[file_selection_20260908_233612/VERIFICATION.md](<F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/file_selection_20260908_233612/VERIFICATION.md>)。

## 2026-09-09 DA766 / DA9726刻度文件名兼容修复

- `converter.dac.runScale`的十六进制CODE/COADE解析现允许码值后带`_JG18_CH1...`、`_CH2`等采集信息；新增类测试覆盖元数据后缀。十进制分支仍保持严格，避免将`7FFF`错误读成十进制7。
- DA9726 `dac_scale_analysis`恢复当前DAC1_JG18真实批次配置：`hex_unsigned`、`raw_unsigned_code`、1001000 Hz、配置版本0.1.1。9个MAT真实运行成功，8点进入拟合，斜率1.01451391294771e-4 V/code、R²=0.999984119899267，与2026-08-20审核结果一致。
- DA766 `dac_scale_hex_analysis`版本0.1.1分别处理X7标准A批次（8文件，斜率3.05017118827885e-4 V/CodePp）和历史CH2/B批次（5文件，斜率3.07861129326612e-4 V/CodePp）；两批混选被拒绝。误用十进制入口会在创建结果前提示正确入口。
- 生产代码checkcode均0项，`dacCoreTest` 7/7通过；三次最终真实运行均SUCCESS，22份输入的清单SHA-256无缺失、无不匹配。原始MAT未改。入口和数值复现已验证；负载、参考面和正式需求仍未闭环，方法状态不升级为正式已验证。证据：[VERIFICATION.md](<F:/01_Laser/.codex_work/20260909-dac-scale-code-parsing/VERIFICATION.md>)。

## 2026-09-17 DA766噪声默认目录失效修复

公共 selectCaptureFiles 在文件列表为空、起始目录不存在时回退 pwd 并打开选择框；显式文件列表仍严格验证目录。DA766 README同步。MATLAB R2025b验证零参数取消、失效目录取消、选择后路径更新、显式错误路径拒绝以及checkcode通过（UI桩测试，未人工点击窗口、未重算真实噪声）。证据：F:/01_Laser/.codex_work/20260917-da766-path/matlab.log。未修改噪声公式或数据。


## 2026-09-17 MAT纯切分入口

split_dac_isolation_channels v0.2.0只切分A/B/C/D并记录接口、时基和哈希；移除驱动接口、目录频率、正弦拟合及配对模板生成。保留文件名JG顺序/显式channelMapping映射。真实JG25-1M目录中四通道文件单独切分4路、单D文件单独切分1路均通过；波形/时基/源哈希一致；checkcode零问题，3项相关回归通过（含另行显式构建配对后的隔离度计算）。证据：F:/01_Laser/.codex_work/20260917-jg25-isolation/pure_split.log。原始数据和历史结果不改，方法审计状态不升级。

## 2026-09-20 准确性修订、十六进制兼容和精简输出

| 范围 | 有证据状态 | 证据与限制 |
|---|---|---|
| ADC CSV进制读取 | 定向测试通过；真实十/十六进制等价 | 23项测试覆盖歧义/边界/非法/valid/131072点及双通道所选列识别；AD677 X3两种表示逐字段一致。仅选定ADC列转换 |
| 精简XLSX和evidence布局 | 结构与数值类型验证通过 | `summaryWorkbookTest`、MATLAB/readcell及openpyxl均可读；报告层不重算指标，历史结果不迁移 |
| ADC方法门控 | 合成/集成验证通过，方法仍有限制 | THD/SFDR、带宽、隔离度、INL/DNL门控见本次报告；无真实数据的入口不升级方法状态 |
| 噪声和DAC | 定向回归通过；DA9726刻度真实复现 | 噪声增益100只补偿一次；PICO通道/覆盖严格；实际噪声和隔离度硬件条件未全面复跑 |
| 全库回归 | 首轮176项中174通过、2项输出整理失败；修复后定向补跑 | 两项为解码表追加及空隔离工作簿，不是算法数值失败；最终定向结果见implementation/final_targeted*.csv |
| AD9245真实黄金回归 | 已运行，未通过旧签名 | 显式固定十进制/25 MHz/全点SFDR后四入口均执行；最终`converter:test:GoldenMismatch`。本轮字段和状态已变，历史黄金CSV未修改，证据见implementation/golden_regression_2.log及golden_regression_error.txt |
| 清单与文档 | 已核对 | 144个`.m`、25正式入口；脚本矩阵即时SHA-256零漂移 |

正式报告：`F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20260920_revision/AUDIT_REPORT.md`。脚本矩阵：同目录`SCRIPT_MATRIX.csv`；入口说明：`ENTRYPOINTS.md/ENTRYPOINTS.csv`。测试证据：`F:/01_Laser/.codex_work/20260920-cw513-current-audit/implementation`。真实AD677证据：`F:/01_Laser/0_20260727_513test/20260919_data/JIAQIANGJIAN/AD677/SCALE/ad677_X3_scale_1kHz_amplitude_sweep_20260919_110838_838458/results/cw513_revision_20260920_222108`；真实DA9726证据：`F:/01_Laser/0_20260727_513test/20260919_data/results/20260920_script_audit/DA9726/run_20260920_222659_scale`。

方法状态没有因为测试通过而自动升级。参考面、负载、正式限值、全部25入口真实复跑、ADC全码域INL/DNL和DAC INL/DNL仍未闭环。原始数据、历史结果和黄金基线未修改；未提交/推送Git。

## 2026-09-22 JG18噪声实跑与路径检查

指定文件 jg18_2MSPS_20S_CH1_G_100.mat 已用正式入口处理成功，未复现计算异常。实际A通道39556968点，Tinterval对应1977848.15998275 Hz、20.000002427秒。Length/RequestedLength为39556964，ExtraSamples=0，数组多4点，来源未明确；本次保留实际数组且没有删点。

按显式hardwareGain=100，Hann/0.2 Hz/50%重叠共7段：实际频点0.999999979767279 Hz的ASD为2.18227522136936 µV/√Hz，1～100 kHz积分为34.5675720224396 µVrms。负载和参考条件尚未闭环，正式状态暂不能判定。

入口已改为明确传入数据目录时不再查询旧默认盘符；公共噪声流程增加读取、Welch、完整频谱导出和结果整理进度。只改路径查找和提示，不改公式。完整频谱约494万行、CSV约385 MB，导出需要等待。

```matlab
cd('F:/01_Laser/code/matlab/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/9726_hy');
d = 'I:/513_CW_test/CW_Data/513_CW_DATA_jianding/DA9726/20260922/9726 NOISE';
r = dac_noise_analysis(d, {'jg18_2MSPS_20S_CH1_G_100.mat'}, ...
    fullfile(d,'results'), struct('dataVariables',{{'A'}},'hardwareGain',100));
```

真实结果：该数据目录下 results/run_20260922_175311_noise/结果汇总.xlsx。诊断记录：F:/01_Laser/.codex_work/20260922-9726-noise。原始MAT的SHA-256为0AEFB4BE0961B940129D0A390005A29EF81DEB75051C88EDF4376810CB0F0E9B，运行前后保持一致。
