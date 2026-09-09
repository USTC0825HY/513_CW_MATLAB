# 架构与新器件接入

## 依赖方向

```text
器件入口 -> 器件固定配置 -> converter.adc / converter.dac 公共内核
                              |-> converter.io
                              |-> converter.adc 纯计算
                              |-> converter.report
                              `-> converter.runtime
```

五个器件目录提供分析入口和器件参数，公共算法集中在 `_shared`。AD677 仅注册输入频率和输入功率入口。器件入口不得调用 `laser_analysis`、`01_workflows`或历史脚本。纯计算函数不得弹窗；报告层不得重新定义指标公式。

三个 ADC 功率刻度入口共同通过 `converter.adc.estimateCriticalInput` 估计正、负轨首先达到99%数字满量程时的输入。该函数只使用刻度计算中已选入的 `CalibrationIncluded` 点；报告层只显示其结果，不重新拟合。

## 源码与交付包

源码运行时，`private/bootstrapRuntime.m` 优先加载器件包内的 `internal/+converter`，否则加载相邻的 `_shared`。构建后，公共内核被复制到交付包的 `internal/+converter`，因此交付包离开仓库仍能运行。`_release` 是生成物，不进入 Git。

## 新器件接入步骤

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

## 文件选择与参数传递

`converter.io.selectCsvFiles/selectMatFiles` 共用 `selectCaptureFiles`，只选择并验证本次文件；不建结果目录。`resolveInputPath` 使相对文件始终基于声明的数据目录，绝对路径可跨目录，避免当前目录同名文件混入。DAC入口通过 `prepareDacInputs` 解析文件/配置和默认结果根；`prepareDacIsolation` 单独处理配对关系，不把清单当作波形。

取消选择时，在创建结果目录前返回，不调用createRun。传入完整文件、接口和配对信息时不显示对话框。ADC隔离度和ILA噪声使用采集表头或inputChannels确认通道，禁止文件名自动改写驱动条件或选择刻度。对话框只补充缺失的接口、驱动和参考条件，数值仍由公共内核计算。

2208隔离度第四参数按字段覆盖默认配置；9245使用runOptions。9245 PICO保留三参数签名，entries或selectedFiles/interfaces作为显式文件映射；一个接口一次一份，避免核心接口命名文件覆盖。2208 PICO仍单份MAT，固定DA9726系数保持不变。两类PICO入口返回时恢复原路径。
