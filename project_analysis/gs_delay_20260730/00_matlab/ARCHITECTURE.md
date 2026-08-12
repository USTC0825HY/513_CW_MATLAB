# 架构与新器件接入

## 依赖方向

```text
器件入口 -> 器件固定配置 -> converter.adc 工作流
                              |-> converter.io
                              |-> converter.adc 纯计算
                              |-> converter.report
                              `-> converter.runtime
```

`9245_hy` 是用户层，只负责选择分析项目；`_shared` 是开发层。纯计算函数不得弹窗、读取文件、绘图或写结果。报告层不得重新定义指标公式。

## 源码与交付包

源码运行时，`private/bootstrapRuntime.m` 加载相邻的 `_shared`。构建后，公共内核被复制到交付包的 `internal/+converter`，因此交付包离开仓库仍能运行。`_release` 是生成物，不进入 Git。

## 新器件接入步骤

1. 确认器件类型、采样率、位数、码型、数据列、测试项目和验收阈值。
2. 从 `_templates/adc_device` 或 `_templates/dac_device` 复制器件骨架。
3. 只新增器件入口和固定配置；可以复用的逻辑必须进入 `_shared`。
4. 增加单元测试、小型数据夹具和代表性集成测试。
5. 完成独立包验证后才把 `releaseReady` 改为 `true`。

参数未确认时不得创建看似可运行的入口，也不得构建正式包。

## 源码边界

`legacy` 和 `Matlab_AND_ExampleData_lyp` 仅作历史证据，不得加入运行路径。仓库之外的 `MATLAB_Scripts/GS_Data_Analysis` 也是历史参考，不是正式算法来源。正式 AD9245 算法只有 `_shared/+converter/+adc` 中的一套。
