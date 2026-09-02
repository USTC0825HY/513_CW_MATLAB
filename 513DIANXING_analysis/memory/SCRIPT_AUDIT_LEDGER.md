# CW_513_ANALYSIS 脚本方法审计台账

- 建立日期：2026-08-31
- 审计范围：五个正式器件目录、`_shared/+converter`、日常测试和发布工具
- 排除：`_release`、`legacy`、`Matlab_AND_ExampleData_lyp`、`_templates` 和外部旧 workflow

## 状态定义

- `待方法审计`：文件存在，但尚未完成公式、单位、参考面、数据选择和独立复算闭环。
- `审计中`：已开始逐行/逐公式检查，尚有问题或证据待补。
- `有条件可用`：方法基本闭环，但需求、参考面、覆盖或真实数据仍有限制。
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

| 器件 | 脚本 | 指标/责任 | 公共核心或关键依赖 | 当前测试证据 | 方法状态 | 待核对重点 |
|---|---|---|---|---|---|---|
| AD2208 | `2208_hy/adc_sfdr_analysis.m` | SFDR/SNR/SINAD/THD/ENOB | `converter.adc.runSfdr` | `adcCoreTest` 部分覆盖 | 待方法审计 | 100 MHz、FFT/窗/基波谐波掩码、单边谱和单位 |
| AD2208 | `2208_hy/adc_bandwidth_analysis.m` | 输入频率响应和带宽 | `converter.adc.runBandwidth` | `adcCoreTest` 部分覆盖 | 待方法审计 | 文件频率解析、正弦拟合、低频参考、交点与覆盖 |
| AD2208 | `2208_hy/adc_isolation_analysis.m` | 通道隔离度 | `converter.adc.runIsolation` | `adcCoreTest` 部分覆盖 | 待方法审计 | 驱动/受扰配对、参考幅度、频率和 40 dB 限值来源 |
| AD2208 | `2208_hy/adc_power_scale_analysis.m` | `CodePp -> Vpp` 刻度 | `converter.adc.runPowerScale` | `adcCoreTest` 部分覆盖 | 待方法审计 | dBm→Vpp 阻抗、正弦拟合、削顶/平台、拟合范围和反向式 |
| AD2208 | `2208_hy/adc_inl_dnl_analysis.m` | 正弦码密度 INL/DNL | `converter.adc.runInlDnl` | `adcCoreTest` 部分覆盖 | 待方法审计 | 多记录独立性、概率模型、码端余量、有效记录比例和 R² |
| AD2208 | `2208_hy/adc_input_noise_analysis.m` | ADC 输入等效噪声 | `converter.adc.runInputNoise` | `adcCoreTest` 部分覆盖 | 待方法审计 | 码到电压刻度、Welch/PSD、10–25 MHz 频带和 300 nV/√Hz 来源 |
| AD2208 | `2208_hy/run_ad2208_batch.m` | 自动分组批处理 | 上述入口 | 无独立集成基线 | 待方法审计 | 数据树、文件选择、重复数据、错误隔离和汇总状态 |
| AD2208 | `2208_hy/run_ad2208_isolation_batch.m` | 隔离度配对批处理 | `adc_isolation_analysis` | 无独立集成基线 | 待方法审计 | 文件名配对、20 组矩阵、缺失/重复配对 |
| AD2208 | `2208_hy/ad2208_build_input_coverage.m` | 输入覆盖与哈希清单 | runtime SHA-256 | 无独立测试 | 待方法审计 | 文件范围、哈希、重复文件和结果目录排除 |
| AD2208 | `2208_hy/audit_ad2208_results.m` | 结果包审计 | runtime/清单 | 无独立测试 | 待方法审计 | 必需文件、输入哈希、失败状态和过期结果识别 |
| AD2208 | `2208_hy/private/ad2208Config.m` | 16 bit/100 MHz/第4列及限值 | `converter.runtime.validateConfig` | 间接受单元测试覆盖 | 待方法审计 | 每个指标的采样率、阈值、数据列和需求版本 |
| AD2208 | `2208_hy/private/bootstrapRuntime.m` | 运行内核解析 | `internal` 或 `_shared` | `portabilityTest` 间接覆盖 | 待方法审计 | 禁止旧 workflow 回退、路径污染和函数缓存 |
| AD9245 | `9245_hy/adc_sfdr_analysis.m` | 动态指标 | `converter.adc.runSfdr` | AD9245 集成测试和黄金 CSV | 待方法审计 | 20 MHz 采样、FFT/窗、掩码、黄金来源 |
| AD9245 | `9245_hy/adc_bandwidth_analysis.m` | 输入频率响应和带宽 | `converter.adc.runBandwidth` | AD9245 集成测试和黄金 CSV | 待方法审计 | 实际采样率覆盖、参考点和无 −3 dB 交点处理 |
| AD9245 | `9245_hy/adc_isolation_analysis.m` | 通道隔离度 | `converter.adc.runIsolation` | AD9245 集成测试和黄金 CSV | 待方法审计 | 驱动端、受扰端、频率、参考面和矩阵完整性 |
| AD9245 | `9245_hy/adc_power_scale_analysis.m` | `CodePp -> Vpp` 刻度 | `converter.adc.runPowerScale` | AD9245 集成测试和黄金 CSV | 待方法审计 | dBm→Vpp、50 Ω 条件、拟合方向和削顶点 |
| AD9245 | `9245_hy/adc_inl_dnl_analysis.m` | 正弦码密度 INL/DNL | `converter.adc.runInlDnl` | AD9245 集成测试和黄金 CSV | 待方法审计 | 码密度理论、拟合 R²、异常毛刺和巨大 INL 的真实性 |
| AD9245 | `9245_hy/adc_input_noise_analysis.m` | AD9245→FPGA G=128→DA9726 JG18 1 Hz 输入等效噪声 | `noise_chain_hy/adc_input_equiv_noise_analysis` | X3G/X4G 20 s Pico MAT 真实数据验证 | 待方法审计 | ADC/JG18 刻度来源、Pico 参考面、总链路本底、1 Hz 估计方差、X1G/X2G 截断记录 |
| AD9245 | `9245_hy/private/ad9245Config.m` | 14 bit/采样率/数据列及限值 | `converter.runtime.validateConfig` | AD9245 集成测试 | 待方法审计 | 指标实际采样率、默认列识别和限值来源 |
| AD9245 | `9245_hy/private/bootstrapRuntime.m` | 运行内核解析 | `internal` 或 `_shared` | `portabilityTest` 间接覆盖 | 待方法审计 | 独立包与开发库数值一致性 |
| AD677 | `677_hy/adc_bandwidth_analysis.m` | 输入频率响应 | `converter.adc.runBandwidth` | `ad677ContractTest`、`ad677WorkflowTest` | 待方法审计 | 100 MHz ILA 保持码、valid 脉冲、实际转换率和覆盖 |
| AD677 | `677_hy/adc_power_scale_analysis.m` | `CodePp -> Vpp` 刻度 | `converter.adc.runPowerScale` | `ad677ContractTest`、`ad677WorkflowTest` | 待方法审计 | High-Z 显示 Vpp、板端参考面、setpoint manifest 和削顶 |
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
| `calculatePowerScale.m` | `CodePp -> Vpp` 线性拟合 | `adcCoreTest` | 待方法审计 | 拟合方向、权重、有效范围、残差、R²和反向式 |
| `codePpToInputPowerDbm.m` | 由刻度反算等效 dBm | `adcCoreTest` 部分覆盖 | 待方法审计 | 只能作为明确阻抗下的派生量，不能取代正式 Vpp 刻度 |
| `dbmToVpp.m` | dBm→Vpp | `adcCoreTest` 部分覆盖 | 待方法审计 | RMS/峰峰值公式、阻抗、标量/向量和非法输入 |
| `estimateFrequency.m` | 初始频率估计 | `adcCoreTest` 部分覆盖 | 待方法审计 | DC 去除、窗、频率栅格、低频和近 Nyquist |
| `findAccuratePeak.m` | 频谱峰值细化 | `adcCoreTest` 部分覆盖 | 待方法审计 | 插值模型、边界 bin 和幅值修正 |
| `findThreeDbCrossing.m` | −3 dB 交点搜索 | `adcCoreTest` 部分覆盖 | 待方法审计 | 单调假设、覆盖不足和插值域 |
| `fitSine.m` | 正弦拟合 | `adcCoreTest` | 待方法审计 | 频率固定/自由、偏置、幅值、相位、R²和残差 |
| `refineSineFrequency.m` | 正弦频率精细化 | `adcCoreTest` 部分覆盖 | 待方法审计 | 搜索范围、局部极值、样本时基和收敛失败 |
| `runBandwidth.m` | 带宽完整工作流 | `adcCoreTest`、AD9245/AD677 集成测试 | 待方法审计 | IO→拟合→归一化→交点→状态的完整一致性 |
| `runInlDnl.m` | INL/DNL 完整工作流 | `adcCoreTest`、AD9245 集成测试 | 待方法审计 | 多记录合并、有效比例、异常记录和输出字段 |
| `runInputNoise.m` | ADC 输入等效噪声工作流 | `adcCoreTest` 部分覆盖 | 待方法审计 | 码值标定、PSD/ASD、积分和参考面 |
| `runIsolation.m` | ADC 隔离度完整工作流 | `adcCoreTest`、AD9245 集成测试 | 待方法审计 | 配对、通道识别、参考幅度和矩阵/最差值 |
| `runPowerScale.m` | ADC 刻度完整工作流 | `adcCoreTest`、AD9245/AD677 集成测试 | 待方法审计 | setpoint 来源、有效点、正式字段和图表一致性 |
| `runSfdr.m` | SFDR 完整工作流 | `adcCoreTest`、AD9245 集成测试 | 待方法审计 | FFT 归一化、指标口径、文件频率和失败条件 |
| `vppToDbm.m` | Vpp→dBm 派生换算 | `adcCoreTest` 部分覆盖 | 待方法审计 | 明确阻抗、反函数一致性和高阻数据标记 |

## DAC 公共计算

| 脚本 | 责任 | 当前测试证据 | 方法状态 | 待核对重点 |
|---|---|---|---|---|
| `_shared/+converter/+dac/fitTone.m` | DAC/Pico 正弦拟合 | `dacCoreTest` | 待方法审计 | 时基、偏置、幅值/Vpp、频率和拟合质量 |
| `loadPicoMat.m` | DAC 层 Pico MAT 兼容入口 | `dacCoreTest` 部分覆盖 | 待方法审计 | 与 `converter.io.loadPicoMat` 的唯一实现关系、通道/单位 |
| `runScale.m` | DAC 刻度工作流 | `dacCoreTest` | 待方法审计 | Code/Vpp 方向、文件名解析、排除点和 R² |
| `runNoise.m` | Welch PSD/ASD 与积分噪声 | `dacCoreTest` | 待方法审计 | 窗功率归一化、单边谱、分段/重叠、积分频带、增益回退 |
| `runIsolation.m` | DAC 隔离度工作流 | `dacCoreTest` | 待方法审计 | pair manifest、参考音调、幅度比、通道/频率和状态 |

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
