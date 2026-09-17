# CW_513_ANALYSIS 项目记忆

2026-09-17：新增 `CW_analysis/CW_513_ANALYSIS/128_hy/adc_bandwidth_analysis.m`，ADC128为用户确认的12 bit ADC，unsigned输入，采样率必须显式提供或交互填写。沿用公共带宽算法，全正正弦通过DC项拟合；未注册独立发布。7频点合成运行、DC平移不变性、交点、Nyquist拒绝和3文件checkcode通过；未验证实测CSV。证据位于 `F:/01_Laser/.codex_work/20260917-adc128-bandwidth`。

- 建档日期：2026-08-31
- 文档修订：2026-09-15
- 主分析库：`F:\01_Laser\code\matlab\513DIANXING_analysis\CW_analysis\CW_513_ANALYSIS`
- 当前数据根：`F:\01_Laser\0_20260727_513test\CW_Data\513_CW_DATA`
- 当前文档根：`F:\01_Laser\0_20260727_513test\03_CW测试\01_Documents_文档`

本文件汇总工程结构、器件配置和已知问题。具体测试条件仍需查看测试细则、原始数据、仪器设置和对应的 RTL/XDC、MATLAB 实现。文档与代码不一致时，先查明原因并修正，再交付正式结果。

## 工程结构

2026-09-09用户要求取消INL/DNL额外码端裁剪：AD2208、AD9245的 `marginCode` 均改为0；仍取有效记录拟合范围交集并限制合法码域，不放大到满量程。质量门槛和公式不变，原marginCode=1000的历史结果不覆盖。

### 2026-09-09 报告刻度更新

`CW_analysis/CW_513_ANALYSIS/_shared/+converter/+calibration/reportCalibration.m` 保存 `SZSD_YCQD测试结果__20260903.docx` 中20条刻度：AD2208五路、AD9245四路、DA766八路、AD677两路和DA9726 JG18斜率。采用独立刻度表，不采用噪声章节旧ADC系数。五器件private配置加载对应记录；2208 ILA已补JG19/JG24，2208和9245 PICO默认读取随代码提供的配置，仍可显式指定旧工作簿。2208 PICO的JG18高精度固定值保留。采样率和噪声算法未改。memory和AGENTS不发布。

本地高频ILA目录的 `JG19.csv` 表头为yb2208模块0（ADC1/JG15），不是模块2；不能按文件名判为JG19，需核对采集来源。

```text
513DIANXING_analysis/
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
      noise_chain_hy/
      _templates/
      tests/
      tools/
```

正式源码位于五个器件目录、`_shared/+converter` 和PICO噪声模块 `noise_chain_hy`。`_release` 是生成物，现已与 `legacy` 一起移出日常运行目录，归档位置见后文。`Matlab_AND_ExampleData_lyp` 仅用于历史对比，不加入运行路径。

## 器件和入口状态

| 器件 | 正式入口范围 | 配置 | 当前结论边界 |
|---|---|---|---|
| AD2208/YB2208 | SFDR、输入频率响应、隔离度、`CodePp -> Vpp` 刻度及99%临界输入估计、INL/DNL、直接 ILA 噪声与 PICO 1 Hz 联合噪声；共7个单项入口 | `2208_hy/private/ad2208Config.m` | `releaseReady=true`；每项正式结论仍须核对需求、参考面和数据覆盖 |
| AD9245 | SFDR、输入频率响应、隔离度、`CodePp -> Vpp` 刻度及99%临界输入估计、INL/DNL、经 DA9726 JG18/G=128 链路折算的 1 Hz 输入等效噪声 | `9245_hy/private/ad9245Config.m`；噪声入口固定 JG18 刻度源 | `releaseReady=true`；噪声默认不扣 DA/Pico 本底，记录完整性、参考面或需求未确认时，不能判为正式满足 |
| AD677 | 输入频率响应、`CodePp -> Vpp` 刻度及99%临界输入外推；ILA噪声；经DA9726 JG18/G=128折算的PICO 1 Hz输入等效噪声；批处理和结果审计 | `677_hy/private/ad677Config.m` | `formalEnabled=false`；高阻信号源显示 Vpp 的板端参考面和终端未确认；噪声无正式限值；短PICO记录不能用于1 Hz ASD |
| DA9726 | DAC 刻度/正弦输出Vpp、输出噪声、隔离度；共3个单项入口 | `9726_hy/private/da9726Config.m` | `formalEnabled=false`；需求来源和参考条件未完全确认 |
| DA766 | DAC 通用/十六进制刻度、输出噪声、隔离度；共4个单项入口 | `766_hy/private/da766Config.m` | `formalEnabled=false`；需求版本存在冲突 |

当前不属于正式入口的内容：

- DA 相位噪声；
- DA 独立DC输出电压和DAC INL/DNL（正弦输出Vpp已由刻度脚本提供）；
- DA766 更新率/分辨率；
- AD677 的 SFDR、隔离度和 INL/DNL；
- 未进入五个器件目录和公共内核的历史 workflow。

## 公共内核

| 模块 | 责任 | 主要入口 |
|---|---|---|
| `converter.adc` | ADC 动态指标、带宽、隔离度、刻度、99%临界输入估计、INL/DNL、输入噪声和正弦/频率拟合 | `runSfdr`、`runBandwidth`、`runIsolation`、`runPowerScale`、`estimateCriticalInput`、`runInlDnl`、`runInputNoise` |
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

测试通过说明相应用例通过，不表示所有测量方法都已验证。公式、单位、参考面、数据选择和独立复算的检查情况见 `SCRIPT_AUDIT_LEDGER.md`。

## 已知不一致和待办

1. AD9245旧ILA数据为25 MHz，后续计划改为20 MHz。当前 `ad9245Config.m` 默认仍为25 MHz；实际用20 MHz采集的新数据需调整分析参数，旧数据继续用25 MHz。此前 `METRICS.md` 将旧ILA数据写成20 MHz有误，现已更正；ADC转换时钟20 MHz与旧ILA时钟25 MHz需分开记录。
2. AD2208 旧 README 曾引用不存在的旧测试根路径，现已改为当前 `0_20260727_513test` 数据根。
3. 代码默认目录名是 `results`，不是 `result`；显式指定目录除外。
4. DA9726/DA766 的 `formalEnabled` 关闭，不能仅凭数值低于限值就判为合格。
5. AD677 当前只有方法和数据处理入口，没有独立正式操作手册，正式合格判据也未确认。
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

采用与上述优先顺序不同的来源时，需写明原因，不能直接替换原记录。

## 维护规则

- 新增器件或指标：同步更新本文件、总 README、`ARCHITECTURE.md`、`METRICS.md` 和审计台账。
- 修改算法：同步更新测试、黄金基线和审计证据。
- 修改数据或文档根路径：同步更新本文件、相关 README 和本地维护配置。
- 调整操作手册状态：需核对总索引、适用条件、原始数据和结果记录。

## 2026-09-08 日常路径清理

历史实现 legacy/、生成发布副本 _release/、三个固定日期批次驱动和未被正式 CodePp→Vpp 流程引用的 codePpToInputPowerDbm.m 已移入 F:\01_Laser\research_assets\CW_513_ANALYSIS_archive\20260908。它们不再属于日常 MATLAB 运行区；逐文件哈希和恢复说明见该目录的 CLEANUP_RECORD.md 与 cleanup_manifest.csv。

converter.dac.loadPicoMat.m 因 tests/unit/dacCoreTest.m 直接调用而保留。noise_chain_hy/ 是当前 AD9245/AD2208 PICO 联合噪声链的一部分；清理前发现其工作树状态异常，已使用审计开始时的源码快照恢复。

## 2026-09-08 单项噪声入口与使用说明

- 2208直接ILA噪声改名为 `adc_ila_noise_analysis.m`，旧名不保留；新增 `adc_pico_noise_1hz_analysis.m`，零参数选择一份PICO MAT并确认接口，显式调用必须提供interface。
- PICO入口沿用当前noise_chain公式；AD2208使用的DA9726 JG18斜率固定为1.01451391294771e-4 V/CodePp，不查找或读取DAC刻度CSV。ADC刻度继续读工作簿。默认FPGA增益128、Hann/0.2 Hz/50%、不扣本底；记录固定刻度来源和入口/内核/输入SHA-256。共用噪声内核只加载_shared，不递归加载整个库。
- 2208/9245/9726/766分别有7/6/3/4个单项入口。四份README_先看.md逐入口说明签名、参数、选择和输出；当前DAC允许省略输出目录，2208隔离度第四参数按字段覆盖默认配置。
- 该变更没有修改数值公式、器件默认配置、动态范围算法或历史测试基线；测试与真实回归结果见本次SCRIPT_AUDIT_LEDGER记录。

## 2026-09-08 单项文件选择统一与GitHub发布

- 四器件20入口及677两个入口，零参数选择具体CSV/MAT；不再默认扫描全目录或使用固定文件列表。取消不创建结果；显式文件、接口和配对清单不弹窗。四份README、总README、ARCHITECTURE、METRICS与677说明已同步。
- 相对路径基于指定数据目录，绝对路径保留；检测重复输入和输出重名。默认输出为数据目录下results，直接raw目录使用其同级results（PICO2208保留原raw/results约定）；实际run目录带时间戳。选择框末尾目录分隔符已规范化。
- ILA2208使用单段Hann：welchSegmentCount=1、overlap=0、NFFT=131072；要求输入恰为131072点，不做分段平均。100MHz时频点间距762.939453125Hz；不是PICO的1Hz噪声。数值公式、动态范围、ADC INL/DNL和DAC隔离核心不重写。
- PICO2208 DAC固定系数1.01451391294771e-4，PICO9245独立固定1.014514e-4，均不以文件名推断接口；ADC刻度工作簿仍为外部依赖。
- 120项自动化测试、4项真实数据回归、3项固定系数测试通过；交互取消使用UI桩，不等于人工桌面交互或板级验证。证据：F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/file_selection_20260908_233612/VERIFICATION.md。
- 发布仓库为git@github.com:USTC0825HY/513_CW_MATLAB.git。发布范围为完整CW_513_ANALYSIS及配套说明/记忆，不含原始实测数据、输出结果或已移走历史入口；原MATLAB仓库的GitLab远端与无关修改保持不动。

## 2026-09-09 文档修订

已逐份修改发布库中的18份Markdown，简化重复提醒和修改过程描述，保留参数、公式、函数签名和原测试结论。代码未改，未重新运行MATLAB测试。私人代理规则文件不纳入发布，也不作为仓库内文档链接。

## 2026-09-09 DA刻度文件名兼容修复

- DA9726 DAC1_JG18当前刻度数据按已有2026-08-20成功结果恢复为16位十六进制CODE/COADE、`raw_unsigned_code`和1001000 Hz；MAT实际采样率仍从`Tinterval`读取。9个真实MAT复跑斜率为1.01451391294771e-4 V/code，与旧审核结果一致。
- DA766当前06_scale数据应使用`dac_scale_hex_analysis`。X7标准A批次与历史CH2/B批次均支持，但必须分开选择；两批分别以8点和5点复跑成功。误用十进制`dac_scale_analysis`会在创建结果前提示改用十六进制入口。
- 公共十六进制解析允许码值后带JG/CH/采样信息，同时保留分隔符约束，避免把`7FFF`局部误读。原始MAT未改。生产代码checkcode为0项，`dacCoreTest` 7/7通过；证据在`F:/01_Laser/.codex_work/20260909-dac-scale-code-parsing/VERIFICATION.md`。

## 2026-09-14 AD677 ILA与PICO噪声入口

- 新增 `677_hy/adc_ila_noise_analysis.m` 和 `adc_pico_noise_1hz_analysis.m`。ILA保留全部100 MHz抓取点，valid列只统计有效脉冲数和更新率；PICO按AD677—FPGA G=128—DA9726 JG18链路折算输入等效PSD/ASD。
- AD677噪声斜率固定在 `private/ad677Config.m`：677_1为1.536050e-4 V/code，677_2为1.695154e-4 V/code；DA9726固定使用JG18的1.01451391294771e-4 V/code。噪声入口不读取公共AD677报告刻度、外部工作簿或DAC结果CSV。
- PICO显式运行必须指定接口，采样率只取MAT的Tinterval或fs。默认0.2 Hz分辨率要求至少约5秒；现有约10 ms文件会在创建结果目录前被拒绝。没有正式限值，状态保持“暂不能判定”。
- 已补充定向集成测试、公共文件选择测试和文档。2026-09-14本机MATLAB R2025b启动阶段报文件系统一致性错误，测试与checkcode未实际运行，不能标记为通过。

## 2026-09-15 AD9245旧ILA SFDR抽样

- AD9245 SFDR对旧25 MHz ILA数据改为固定步长抽样：按 `1:5:end` 每5点保留1点，分析采样率为5 MHz，再使用既有周期Hann窗计算FFT；其他AD9245指标和其他器件不使用该规则。
- `ADC_SFDR_summary.csv`新增源/分析样点数、源/分析采样率、步长、抽样模式和结果用途。旧数据标记为“旧25 MHz ILA数据抽样估算”，频谱覆盖到2.5 MHz。
- 20 MHz同步采集必须同时设置源/分析采样率20 MHz和步长1；公共SFDR入口拒绝采样率与步长不一致的配置。
- 已补集成测试，但本机MATLAB R2025b仍在启动阶段报文件系统一致性错误，测试未实际运行。

## 2026-09-17 DA766噪声默认目录失效修复

公共 selectCaptureFiles 在文件列表为空、起始目录不存在时回退 pwd 并打开选择框；显式文件列表仍严格验证目录。DA766 README同步。MATLAB R2025b验证零参数取消、失效目录取消、选择后路径更新、显式错误路径拒绝以及checkcode通过（UI桩测试，未人工点击窗口、未重算真实噪声）。证据：F:/01_Laser/.codex_work/20260917-da766-path/matlab.log。未修改噪声公式或数据。


## 2026-09-17 MAT纯切分入口

split_dac_isolation_channels v0.2.0只切分A/B/C/D并记录接口、时基和哈希；移除驱动接口、目录频率、正弦拟合及配对模板生成。保留文件名JG顺序/显式channelMapping映射。真实JG25-1M目录中四通道文件单独切分4路、单D文件单独切分1路均通过；波形/时基/源哈希一致；checkcode零问题，3项相关回归通过（含另行显式构建配对后的隔离度计算）。证据：F:/01_Laser/.codex_work/20260917-jg25-isolation/pure_split.log。原始数据和历史结果不改，方法审计状态不升级。
