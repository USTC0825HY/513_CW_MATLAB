# 架构与新器件接入

## 依赖方向

```text
器件入口 -> 器件固定配置 -> converter.adc / converter.dac 公共内核
                              |-> converter.io
                              |-> converter.adc 纯计算
                              |-> converter.report
                              `-> converter.runtime
```

五个器件目录是用户层，只负责选择分析项目和固定参数；`_shared` 是唯一公共内核。AD677 仅注册输入频率和输入功率入口。器件入口不得调用 `laser_analysis`、`01_workflows`或历史脚本。纯计算函数不得弹窗；报告层不得重新定义指标公式。

## 源码与交付包

源码运行时，`private/bootstrapRuntime.m` 优先加载器件包内的 `internal/+converter`，否则加载相邻的 `_shared`。构建后，公共内核被复制到交付包的 `internal/+converter`，因此交付包离开仓库仍能运行。`_release` 是生成物，不进入 Git。

## 新器件接入步骤

1. 确认器件类型、采样率、位数、码型、数据列、测试项目和验收阈值。
2. 从 `_templates/adc_device` 或 `_templates/dac_device` 复制器件骨架。
3. 只新增器件入口和固定配置；可以复用的逻辑必须进入 `_shared`。
4. 增加单元测试、小型数据夹具和代表性集成测试。
5. 完成独立包验证后才把 `releaseReady` 改为 `true`；`formalEnabled` 单独控制需求结论是否允许判定。

参数未确认时入口可以输出“未测试”或“暂不能判定”，不得伪造满足结论。此时仍可构建用于迁移和复核的非正式交付包，但不得把它当作正式指标包。

## 源码边界

`legacy` 和 `Matlab_AND_ExampleData_lyp` 仅作历史证据，不得加入运行路径。仓库之外的 `MATLAB_Scripts/GS_Data_Analysis` 也是历史参考，不是正式算法来源。正式ADC算法位于 `_shared/+converter/+adc`，DA刻度、噪声和隔离度位于 `_shared/+converter/+dac`。

`9245_hy/adc_input_noise_analysis.m` 是 AD9245 专用的薄入口：它只固化 X1G–X4G、
FPGA `G=128` 和 DA9726 JG18 刻度来源；PSD/ASD 与输入等效换算由
`noise_chain_hy/adc_input_equiv_noise_analysis.m` 和 `_shared/+converter` 执行。
该入口不依赖 `laser_analysis/01_workflows/s09_*` 的运行时路径。
