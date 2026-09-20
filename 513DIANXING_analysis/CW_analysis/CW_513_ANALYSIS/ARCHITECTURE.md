# 架构与新器件接入

## 依赖方向

```text
器件入口 -> 器件固定配置 -> converter.adc / converter.dac 公共内核
                              |-> converter.io
                              |-> converter.adc 纯计算
                              |-> converter.report
                              `-> converter.runtime
```

六个器件目录提供分析入口和器件参数，公共算法集中在 `_shared`。AD677注册输入频率和输入功率入口，并提供ILA与PICO噪声入口。器件入口不得调用 `laser_analysis`、`01_workflows`或历史脚本。纯计算函数不得弹窗；报告层不得重新定义指标公式。

三个 ADC 功率刻度入口共同通过 `converter.adc.estimateCriticalInput` 估计正、负轨首先达到99%数字满量程时的输入。该函数只使用刻度计算中已选入的 `CalibrationIncluded` 点；报告层只显示其结果，不重新拟合。

AD9245 SFDR当前默认20 MHz源时基、每5点取1点、4 MHz分析时基；旧25 MHz记录需显式配置25 MHz和抽取后5 MHz。抽样仅在9245 SFDR配置启用；公共内核校验分析采样率等于源采样率除以步长，并在结果表记录抽样模式和用途。20 MHz同步采集使用步长1。

## 源码与交付包

源码运行时，`private/bootstrapRuntime.m` 优先加载器件包内的 `internal/+converter`，否则加载相邻的 `_shared`。构建后，公共内核被复制到交付包的 `internal/+converter`，因此交付包离开仓库仍能运行。`_release` 是生成物，不进入 Git。

## 新器件接入步骤

ADC128新增 `128_hy/adc_bandwidth_analysis.m` 和 `private/adc128Config.m`，复用2208所用的公共带宽流程。12 bit unsigned经IO减2048归一到公共码域；直流偏置由正弦拟合截距吸收，近轨检查对应原始0～4095。入口要求明确采样率并预检码域、文件频率和Nyquist范围；不加载其他器件配置。当前未注册独立发布包，保留 `releaseReady=false`。

1. 确认器件类型、采样率、位数、码型、数据列、测试项目和验收阈值。
2. 从 `_templates/adc_device` 或 `_templates/dac_device` 复制器件骨架。
3. 只新增器件入口和固定配置；可以复用的逻辑必须进入 `_shared`。
4. 增加单元测试、小型数据夹具和代表性集成测试。
5. 完成独立包验证后才把 `releaseReady` 改为 `true`；`formalEnabled` 单独控制需求结论是否允许判定。

参数未确认时，状态应为“未测试”或“暂不能判定”。这时可以构建用于迁移和复核的非正式交付包，但不能用于正式指标验收。

## 源码边界

`legacy` 和 `Matlab_AND_ExampleData_lyp` 仅作历史证据，不得加入运行路径。仓库之外的 `MATLAB_Scripts/GS_Data_Analysis` 也是历史参考，不是正式算法来源。正式ADC算法位于 `_shared/+converter/+adc`，DA刻度、噪声和隔离度位于 `_shared/+converter/+dac`。

`9245_hy/adc_input_noise_analysis.m` 是 AD9245 专用入口，负责设置 X1G–X4G、
FPGA `G=128` 和 DA9726 JG18 刻度来源；PSD/ASD 与输入等效换算由
`noise_chain_hy/adc_input_equiv_noise_analysis.m` 和 `_shared/+converter` 执行。
该入口不依赖 `laser_analysis/01_workflows/s09_*` 的运行时路径。

`2208_hy/adc_ila_noise_analysis.m` 为原直接 ILA 噪声入口改名，计算仍在
`converter.adc.runInputNoise`。`2208_hy/adc_pico_noise_1hz_analysis.m` 负责单份
MAT 的选择、接口校验和刻度来源设置，调用现有 `noise_chain_hy` 公共内核；
不复制噪声公式。PICO 内核仅加入相邻 `_shared`，不再递归加入所有器件目录。
新入口返回时恢复调用前 MATLAB 路径，记录入口/内核哈希及刻度来源。
AD2208 PICO入口的DA9726斜率固定为1.01451391294771e-4 V/CodePp；
ADC刻度默认来自 `_shared/+converter/+calibration/reportCalibration.m`，显式指定工作簿时才读取外部文件；不查找或读取DA9726刻度CSV。

`677_hy/adc_ila_noise_analysis.m` 复用 `converter.adc.runInputNoise`，但保留
全部100 MHz ILA抓取点，valid列只统计脉冲数和有效更新率。AD677噪声斜率
直接保存在 `private/ad677Config.m`，不读取公共报告刻度。`677_hy/adc_pico_noise_1hz_analysis.m`
复用 `noise_chain_hy`，固定DA9726 JG18斜率和G=128；接口必须由用户选择或显式指定，
采样率来自MAT时基。频率覆盖检查在建立结果目录之前完成。

## 文件选择与参数传递

`converter.io.selectCsvFiles/selectMatFiles` 共用 `selectCaptureFiles`，只选择并验证本次文件；不建结果目录。`resolveInputPath` 使相对文件始终基于声明的数据目录，绝对路径可跨目录，避免当前目录同名文件混入。DAC入口通过 `prepareDacInputs` 解析文件/配置和默认结果根；`prepareDacIsolation` 单独处理配对关系，不把清单当作波形。

DA9726 的 `dac_noise_analysis` 与 `dac_scale_analysis` 只共用上述输入管理，不存在刻度脚本调用噪声脚本或反向调用。`9726_hy/private/resolveDa9726DataFolder.m` 只为零参数运行提供可用的选择框起始目录，优先读取 `CW513_DATA_ROOT` 等环境变量和已存在的数据目录；显式传入 `dataFolder`/`inputFiles` 时始终以调用者参数为准。噪声 MAT（如 `JG18.mat`）没有码值标签，不能作为刻度拟合输入。

噪声内核在创建运行目录前先读取首个选定 MAT；`converter.io.loadPicoMat` 将未完成复制、截断或损坏的文件包装为 `converter:io:MatReadFailed`，记录文件大小并保留原始 MATLAB 错误。该错误只能通过重新导出或完整复制原始 MAT 解决，不能由分析代码补齐波形。

`9726_hy/split_dac_isolation_channels.m` 仅负责多通道PICO MAT切分：按文件名JG顺序或显式channelMapping映射实际A/B/C/D变量，输出统一变量A的单通道派生MAT与来源清单。切分不解析父目录、不要求驱动通道、不拟合频率、不生成配对模板；隔离度条件由dac_isolation_analysis负责。原始MAT不修改。

取消选择时，在创建结果目录前返回，不调用createRun。传入完整文件、接口和配对信息时不显示对话框。DA9726隔离度的简化交互先单选驱动、再多选受扰；接口来自切分MAT元数据或文件名前缀，驱动频率由 `converter.dac.estimateToneFrequency` 统一搜索，未知阻抗/探头信息写入限制而不伪造。隔离度报告将长表 `isolation_db` 同步整理为驱动×受扰矩阵，输出 `dac_isolation_matrix_db.csv` 及按有限 dB 值自适应范围的矩阵热力图；40 dB参考阈值不再用于设置图轴范围。DA766继续使用原逐对条件输入。ADC隔离度和ILA噪声仍使用采集表头或inputChannels确认通道，禁止文件名自动改写驱动条件或选择刻度。

2208隔离度第四参数按字段覆盖默认配置；9245使用runOptions。9245 PICO保留三参数签名，entries或selectedFiles/interfaces作为显式文件映射；一个接口一次一份，避免核心接口命名文件覆盖。2208 PICO仍单份MAT，固定DA9726系数保持不变。两类PICO入口返回时恢复原路径。

## 2026-09-20 输入和输出合同

CSV基数解析统一位于 `converter.io.readAdcCsv/resolveAdcInputRadix`；交互询问由入口前置 `prepareAdcRadix` 完成。只有选中数据列按指定基数解码；valid列仍按0/1处理。缺失、非法或越位宽码值直接拒绝，不删点改变时基。实际基数、列、位宽和码制记录在 `evidence/input_decoding.csv`。

所有新结果由 `converter.runtime.finalizeBundle` 整理：根目录仅保留精简 `结果汇总.xlsx` 和PNG；完整CSV、FIG、配置、完整结果MAT、源码哈希和状态在evidence。共享 `buildSummarySheets` 只挑选已计算字段及换算显示单位，`writeSummaryXlsx` 写标准OOXML数值单元格，不依赖Excel进程。缺少应有字段报错，缺测数值留空。历史结果不迁移；审计读取用 `evidencePath` 兼容旧目录。

本次修改的是主源码。历史ZIP、独立发布目录和旁边的CW_513_CODE没有被更新或删除，不能声称它们已经包含本次修正。