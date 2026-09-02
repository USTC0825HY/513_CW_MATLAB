# CW_513_ANALYSIS 项目代理规则

## 适用范围

本文件适用于 `F:\01_Laser\code\matlab\513DIANXING_analysis` 及其全部子目录。当前正式 MATLAB 分析库是：

`F:\01_Laser\code\matlab\513DIANXING_analysis\CW_analysis\CW_513_ANALYSIS`

当前器件范围为 AD2208、AD9245、AD677、DA9726 和 DA766。除非用户明确要求做历史对比，不得把 `legacy`、`_release`、`Matlab_AND_ExampleData_lyp`、`CW_analysis/MATLAB_Scripts/GS_Data_Analysis`、旧 `laser_analysis/01_workflows` 或外部历史脚本当作正式算法入口。

## 新任务启动顺序

进入本项目的新任务必须先完成以下读取，再选择脚本或处理数据：

1. `memory/PROJECT_MEMORY.md`
2. `CW_analysis/CW_513_ANALYSIS/README.md`
3. `CW_analysis/CW_513_ANALYSIS/ARCHITECTURE.md`
4. `CW_analysis/CW_513_ANALYSIS/METRICS.md`
5. 对应器件目录下的 `README_先看.md`
6. `memory/SCRIPT_AUDIT_LEDGER.md` 中对应指标链
7. 涉及细则、手册或报告时再读 `memory/RESOURCE_INDEX.md`

先盘点实际数据、脚本、配置和证据，再决定运行入口。不得仅凭文件夹名、旧报告或记忆推断测试条件。

## 当前有效路径

- 分析库：`F:\01_Laser\code\matlab\513DIANXING_analysis\CW_analysis\CW_513_ANALYSIS`
- CW 数据：`F:\01_Laser\0_20260727_513test\CW_Data\513_CW_DATA`
- 测试文档：`F:\01_Laser\0_20260727_513test\03_CW测试\01_Documents_文档`
- 测试细则：上述文档根目录内的 `01_Test_Spec_测试细则`
- 操作手册：上述文档根目录内的 `03_Operation_Guide_操作说明与流程图`

不带 `0_` 的旧测试根目录当前不存在，不得写入新脚本、结果或文档示例。

## 架构和依赖

正式依赖方向固定为：

```text
器件入口
  -> 器件 private 固定配置
  -> CW_513_ANALYSIS/_shared/+converter
  -> MATLAB 与明确声明的工具箱
```

- 器件入口只负责参数解析、器件固定配置和调用公共内核。
- 可复用公式只能在 `_shared/+converter` 中保留一份。
- `converter.io` 负责读取和通道/文件名解析。
- `converter.adc`、`converter.dac` 负责计算。
- `converter.report` 负责输出，不得重新定义指标公式。
- `converter.runtime` 负责配置、运行目录、状态、哈希和审计。
- `bootstrapRuntime` 只允许器件包内 `internal/+converter` 或开发库相邻 `_shared/+converter`，不得搜索旧 workflow。

## Skill 路由

任务清单和组合方式以 `memory/RESOURCE_INDEX.md` 为准。常用路由：

- 原始电测数据计算：`laser-electrical-data-analysis`
- MATLAB 方法正确性/代码质量审查：`matlab-review-code`
- 单元、集成、黄金和迁移测试：`matlab-testing`
- MATLAB 重构：`matlab-clean-code`
- 废弃接口迁移：`matlab-modernize-code`
- CW 操作手册：`laser-cw-operation-manual-writing`
- 测试结果文档：`laser-test-report-writing`
- 正式测试报告格式：在上一项基础上追加 `laser-electrical-test-report-standard`
- CW FPGA/固件证据：`laser-cw-qualification-test-development`

调用 skill 后仍必须以实际源文件和测量证据为准；skill 不是采样率、阻抗、参考面或限值的证据。

## 数据和结果安全

- 原始 CSV、MAT、TXT、XLSX、仪器截图和已有结果一律只读。
- 未经用户明确要求，不移动、不重命名、不覆盖、不删除原始数据和历史结果。
- 默认输出根由 `converter.io.resolveOutputBase` 决定：
  - 输入目录名为 `raw` 时，写入与 `raw` 同级的 `results`；
  - 其他输入目录写入其下的 `results`；
  - 用户显式指定输出目录时使用该目录。
- 每次运行使用独立时间戳目录，至少保留输入清单与 SHA-256、参数、数值 CSV、MAT、PNG/FIG、日志及成功/失败状态。
- 取消选择、输入不足或分析失败不得产生“满足”结论。
- 正式结果状态只使用：`满足`、`不满足`、`暂不能判定`、`未测试`。

## 方法学不可变规则

### AD 刻度

- 正式拟合方向固定为 `CodePp -> Vpp`：

  `Vpp = a * CodePp + b`

- 横轴为 `CodePp`，纵轴为 `Vpp`；正式字段使用 `SlopeVppPerCodePp` 和 `InterceptVpp`。
- 原始条件为 dBm 时，只有阻抗和参考面明确后才可先换算：

  `Vpp = 2*sqrt(2*R*1e-3*10^(dBm/10))`

- 默认 50 Ω 仅适用于明确的 50 Ω 条件；高阻设置只能标注“50 Ω 等效换算值”，不能冒充板端实测功率。

### 噪声

- 必须记录采样率、记录时长、窗函数、重叠率、Welch 段长、段数、频率分辨率和单/双边谱定义。
- ASD 的单位和参考面必须明确；积分噪声必须对 PSD 在目标频带积分后开方，禁止直接积分 ASD。
- 放大器增益必须按幅度增益回退到指定参考面。例如 40 dB 电压增益对应除以 100。
- 频带覆盖、分段数或参考面不足时保留数值，但正式结论为“暂不能判定”。

### 频谱、动态指标和图形

- SFDR/SNR/SINAD/THD/ENOB 的基波、谐波、DC、窗函数、FFT 归一化和频率搜索范围必须由代码和参数表共同证明。
- INL/DNL 必须记录码型、有效记录比例、正弦拟合、削顶/毛刺和文件间连续性假设。
- 正式图统一白色 Figure/坐标区、黑色标题/坐标/图例、浅灰网格；黑底或低对比度图视为交付失败。
- 图中的阈值线、频带线和注释必须对应真实需求，不能仅为视觉装饰。

## 逐脚本正确性审计门禁

每次只审计一个完整指标链，顺序为：

1. 输入文件与 IO/通道解析；
2. 器件配置、采样率、码型和参考条件；
3. 公共计算函数及公式/单位；
4. 有效点、排除点、削顶、覆盖和异常处理；
5. 结果表、图片、状态和证据包；
6. 单元测试、合成夹具、真实数据和黄金回归。

审计结果写入 `memory/SCRIPT_AUDIT_LEDGER.md`。存在测试文件不等于方法已验证；只有公式、实现、数据条件、独立复算和回归证据均闭环后，才可把“待方法审计”升级为“已验证”。

若修改公式、单位、有效点规则、阈值或正式状态逻辑，必须在同一变更中同步更新：

- `CW_analysis/CW_513_ANALYSIS/METRICS.md`
- 对应器件 `README_先看.md`
- 单元/集成测试与黄金基线
- `memory/SCRIPT_AUDIT_LEDGER.md`

不得只修改图片、报告或黄金 CSV 来适配新输出。

## 文档和版本边界

- 操作手册按总索引中的 A/B/C/D 状态使用，不能按文件修改时间猜“最新版”。
- “待评审”“草案”“审阅版”不等于正式可执行。
- DA766 是本分析库/数据目录名称；操作手册中常使用 AD766 名称。引用时必须同时写清对象和来源，不能静默混用。
- AD677 当前没有独立正式操作手册。
- 更新项目事实后，先更新 `memory/PROJECT_MEMORY.md`；新增或复核脚本后同步更新审计台账。
