# 数据转换器 MATLAB 分析程序

本仓库采用“公共内核只维护一份、每个器件提供傻瓜式入口、交付时生成独立包”的方式管理。当前正式器件只有 **AD9245**；AD2208、AD766 和 AD9726 均为待确认模板，不能用于正式测试。

## AD9245 使用方法

1. 在 MATLAB 中打开 `9245_hy` 目录。
2. 运行需要的入口：`adc_sfdr_analysis`、`adc_bandwidth_analysis`、`adc_isolation_analysis`、`adc_power_scale_analysis` 或 `adc_inl_dnl_analysis`。
3. 选择测试数据目录，再多选 CSV 文件。
4. 在数据目录的 `results/run_时间_项目` 中查看结果。

测试人员不需要填写采样率、位数、码型或算法参数。固定参数位于 `9245_hy/private/ad9245Config.m`，仅由维护人员修改。

## 维护入口

- 公共读取、算法和输出代码：`_shared/+converter`
- 自动化测试：`tests/run_all_tests.m`
- 构建独立交付包：`tools/buildDeviceRelease.m`
- 架构及接入规则：`ARCHITECTURE.md`
- 指标定义：`METRICS.md`
- 历史代码：`legacy`（不得加入 MATLAB 运行路径）

开发环境以 MATLAB R2025b 自动验证，并避免使用 R2018 不支持的 `arguments`、`readmatrix`、`tiledlayout` 和 `exportgraphics`。
