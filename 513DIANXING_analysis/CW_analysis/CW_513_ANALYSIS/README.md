# CW_513_ANALYSIS 513测试器件分析库

本库只服务513测试的四类器件：AD9245、AD2208、DA9726和DA766。器件入口、公共算法、测试和发布工具全部位于本目录内，运行器件入口不依赖 `laser_analysis`、`01_workflows`或历史脚本。

## 器件入口

- `9245_hy`：SFDR、带宽、隔离度、功率刻度、INL/DNL。
- `2208_hy`：SFDR、带宽、隔离度、功率刻度、INL/DNL。
- `9726_hy`：DA刻度、DA噪声、DA隔离度。
- `766_hy`：DA刻度、DA噪声、DA隔离度。

DA相噪、输出电压、线性度以及DA766更新率/分辨率暂不纳入本库正式入口。DA9726/DA766 当前入口的 `formalEnabled` 保持关闭，结果可用于迁移和复核，但不自动给出正式满足结论。

每个入口都支持显式传入数据目录、文件和输出目录；不传参数时才打开选择框。结果写在输入目录下的 `results/run_时间_指标`，或写入显式指定的输出目录。

## 独立运行

开发模式下，入口只加载相邻的 `_shared/+converter`。发布模式下，`tools/buildDeviceRelease.m` 将公共内核复制到器件包的 `internal/+converter`，器件包可以脱离本目录、`laser_analysis`和原workflow迁移运行。

## 维护入口

- 公共算法和运行时：`_shared/+converter`
- 自动化测试：`tests/run_all_tests.m`
- 独立交付包：`tools/buildDeviceRelease.m`
- 架构规则：`ARCHITECTURE.md`
- 指标定义：`METRICS.md`
- 历史代码：`legacy`，不得加入运行路径
