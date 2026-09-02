# CW_513_ANALYSIS 项目记忆

- 状态日期：2026-08-31
- 主分析库：`F:\01_Laser\code\matlab\513DIANXING_analysis\CW_analysis\CW_513_ANALYSIS`
- 当前数据根：`F:\01_Laser\0_20260727_513test\CW_Data\513_CW_DATA`
- 当前文档根：`F:\01_Laser\0_20260727_513test\03_CW测试\01_Documents_文档`

本文件记录新任务接手所需的当前事实，不替代测试细则、原始数据、仪器设置、RTL/XDC 或 MATLAB 可执行实现。文档与代码不一致时应停止正式交付，查明原因后同步修正。

## 工程结构

```text
513DIANXING_analysis/
  AGENTS.md
  memory/
    PROJECT_MEMORY.md
    RESOURCE_INDEX.md
    SCRIPT_AUDIT_LEDGER.md
  CW_analysis/
    CW_513_ANALYSIS/
      README.md
      ARCHITECTURE.md
      METRICS.md
      2208_hy/
      9245_hy/
      677_hy/
      9726_hy/
      766_hy/
      _shared/+converter/
      _templates/
      tests/
      tools/
      legacy/
      _release/
```

正式源码是五个器件目录和 `_shared/+converter`。`_release` 是生成物，`legacy` 与 `Matlab_AND_ExampleData_lyp` 仅用于追溯，不能进入正式运行路径。

## 器件和入口状态

| 器件 | 正式入口范围 | 配置 | 当前结论边界 |
|---|---|---|---|
| AD2208/YB2208 | SFDR、输入频率响应、隔离度、`CodePp -> Vpp` 刻度、INL/DNL、输入噪声；另有批处理和结果审计 | `2208_hy/private/ad2208Config.m` | `releaseReady=true`；每项正式结论仍须核对需求、参考面和数据覆盖 |
| AD9245 | SFDR、输入频率响应、隔离度、`CodePp -> Vpp` 刻度、INL/DNL、经 DA9726 JG18/G=128 链路折算的 1 Hz 输入等效噪声 | `9245_hy/private/ad9245Config.m`；噪声入口固定 JG18 刻度源 | `releaseReady=true`；噪声默认不扣 DA/Pico 本底，记录完整性、参考面和需求未闭环时不得给出正式满足结论 |
| AD677 | 输入频率响应、`CodePp -> Vpp` 刻度；批处理和结果审计 | `677_hy/private/ad677Config.m` | `formalEnabled=false`；高阻信号源显示 Vpp 的板端参考面/终端未闭合 |
| DA9726 | DAC 刻度、输出噪声、隔离度；批处理和结果审计 | `9726_hy/private/da9726Config.m` | `formalEnabled=false`；需求来源和参考条件未完全固化 |
| DA766 | DAC 刻度、直流噪声、隔离度；批处理和结果审计 | `766_hy/private/da766Config.m` | `formalEnabled=false`；需求版本存在冲突 |

当前不属于正式入口的内容：

- DA 相位噪声；
- DA 输出电压和线性度；
- DA766 更新率/分辨率；
- AD677 的 SFDR、隔离度和 INL/DNL；
- 未进入五个器件目录和公共内核的历史 workflow。

## 公共内核

| 模块 | 责任 | 主要入口 |
|---|---|---|
| `converter.adc` | ADC 动态指标、带宽、隔离度、刻度、INL/DNL、输入噪声和正弦/频率拟合 | `runSfdr`、`runBandwidth`、`runIsolation`、`runPowerScale`、`runInlDnl`、`runInputNoise` |
| `converter.dac` | Pico MAT 加载、正弦拟合、DAC 刻度、噪声和隔离度 | `runScale`、`runNoise`、`runIsolation` |
| `converter.io` | ADC CSV/Pico MAT、通道识别、文件名条件解析、文件选择和输出根解析 | `readAdcCsv`、`loadPicoMat`、`resolveOutputBase` |
| `converter.report` | 数值表和统一图片输出 | `writeTable`、`saveFigure`、`plot*` |
| `converter.runtime` | 运行配置、目录、日志、状态、哈希、清单和结果审计 | `createRun`、`finishRun`、`writeRunManifest`、`auditRun` |

发布包运行时，器件 `private/bootstrapRuntime.m` 优先解析包内 `internal/+converter`，否则使用开发库相邻 `_shared/+converter`；两者均不存在时应报“运行内核缺失”。

## 数据和输出约定

- 原始数据只读。
- 输入目录名为 `raw` 时，默认输出为与其同级的 `results`；其他输入目录默认输出为其内部 `results`。
- 用户显式提供输出目录时，以显式目录为准。
- 每次运行生成独立时间戳结果包。
- 最小证据包括：输入路径、大小、修改时间、SHA-256、运行配置、数值明细、摘要、MAT、图片、日志和状态。
- 旧文档中不带 `0_` 的测试路径已失效，不能继续引用。

## 测试和发布

测试入口：

- `tests/run_all_tests.m`：完整 MATLAB 测试集合。
- `tests/run_golden_regression.m`：黄金回归。
- `tests/run_portability_smoke.m`：迁移/独立运行冒烟测试。

当前可见测试证据：

- `tests/unit/adcCoreTest.m`
- `tests/unit/dacCoreTest.m`
- `tests/unit/ioUtilitiesTest.m`
- `tests/unit/ad677ContractTest.m`
- `tests/integration/ad9245WorkflowTest.m`
- `tests/integration/ad677WorkflowTest.m`
- `tests/integration/portabilityTest.m`
- `tests/golden/ad9245_x3g`

发布工具：

- `tools/buildDeviceRelease.m`：构建设备独立包。
- `tools/deviceReleaseRegistry.m`：器件发布注册。
- `tools/verifyDeviceRelease.m`：独立包静态、依赖和合成数据验证。

存在测试只说明已有自动化证据。方法是否正确仍须按 `SCRIPT_AUDIT_LEDGER.md` 完成公式、单位、参考面、数据选择和独立复算审计。

## 已知不一致和待办

1. `METRICS.md` 的首个通用表保留了早期 AD9245/20 MHz 固定条件，不能套用于 AD2208 的 100 MHz 或 AD677 的 100 MHz ILA 记录；执行时以器件配置和本次采集证据为准，并在后续逐指标审计时拆分器件口径。
2. AD2208 旧 README 曾引用不存在的旧测试根路径，现已改为当前 `0_20260727_513test` 数据根。
3. 代码默认目录名是 `results`，不是 `result`；显式指定目录除外。
4. DA9726/DA766 的 `formalEnabled` 关闭，不得因结果数值看似满足就自动升级结论。
5. AD677 当前只有方法和数据处理入口，没有独立正式操作手册，也未形成正式合格判据闭环。
6. 操作手册总索引仍是草案，所有 A/B/C/D 状态必须保留。
7. `C:\Users\86183\.codex\laser-fpga-profile.json` 的 `cw513_test_data_root` 应与本文件记录的当前数据根一致。

## 事实来源优先级

同一事实冲突时，按以下顺序处理：

1. 原始测量文件、仪器设置、manifest 和源文件哈希；
2. 当前器件配置及 `_shared/+converter` 可执行实现；
3. 当前有效测试细则和正式批准的需求；
4. 与当前固件匹配的 RTL/XDC/BIT/LTX 证据；
5. 当前操作手册索引指定的版本；
6. 测试报告和历史结果；
7. legacy、示例和旧 workflow。

低优先级来源不能静默覆盖高优先级来源。

## 维护规则

- 新增器件或指标：同步更新本文件、总 README、`ARCHITECTURE.md`、`METRICS.md` 和审计台账。
- 修改算法：同步更新测试、黄金基线和审计证据。
- 修改数据或文档根路径：同步更新本文件、`AGENTS.md`、相关 README 和全局 Laser profile。
- 操作手册状态升级：必须有总索引、证据边界、原始数据和结果记录共同支持。
