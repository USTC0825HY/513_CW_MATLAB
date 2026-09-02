# CW_513_ANALYSIS 513测试器件分析库

本库服务513测试的五类器件：AD9245、AD2208、AD677、DA9726和DA766。器件入口、公共算法、测试和发布工具全部位于本目录内，运行器件入口不依赖 `laser_analysis`、`01_workflows`或历史脚本。

当前有效数据根目录为：

`F:\01_Laser\0_20260727_513test\CW_Data\513_CW_DATA`

项目级接手规则和长期记录位于本库上两级：

- [项目代理规则](../../AGENTS.md)：新任务必须遵守的启动、依赖、数据安全和审计规则。
- [项目记忆](../../memory/PROJECT_MEMORY.md)：当前工程、器件和状态记忆。
- [资源与 Skill 索引](../../memory/RESOURCE_INDEX.md)：skill、细则、手册和报告索引。
- [脚本方法审计台账](../../memory/SCRIPT_AUDIT_LEDGER.md)：逐脚本方法正确性审计台账。

## 器件入口

- `9245_hy`：SFDR、带宽、隔离度、`CodePp -> Vpp` 刻度、INL/DNL，以及经 DA9726 JG18/G=128 链路折算的 1 Hz 输入等效噪声。
- `2208_hy`：SFDR、带宽、隔离度、`CodePp -> Vpp` 刻度、INL/DNL、输入噪声。
- `677_hy`：输入频率响应、输入 Vpp—CodePp 刻度；正式结论暂关闭。
- `9726_hy`：DA刻度、DA噪声、DA隔离度。
- `766_hy`：DA刻度、DA噪声、DA隔离度。

DA相噪、输出电压、线性度以及DA766更新率/分辨率暂不纳入本库正式入口。DA9726/DA766 当前入口的 `formalEnabled` 保持关闭，结果可用于迁移和复核，但不自动给出正式满足结论。

每个入口都支持显式传入数据目录、文件和输出目录；不传参数时才打开选择框。默认情况下，输入目录名为 `raw` 时结果写入与 `raw` 同级的 `results/run_时间_指标`，其他输入目录写入其下的 `results/run_时间_指标`；显式指定输出目录时使用指定目录。AD677 批处理遵循同一 `raw`/`results` 同级规则。

## 独立运行

开发模式下，入口只加载相邻的 `_shared/+converter`。发布模式下，`tools/buildDeviceRelease.m` 将公共内核复制到器件包的 `internal/+converter`，器件包可以脱离本目录、`laser_analysis`和原workflow迁移运行。

## 维护入口

- 公共算法和运行时：`_shared/+converter`
- 自动化测试：`tests/run_all_tests.m`
- 独立交付包：`tools/buildDeviceRelease.m`
- 架构规则：`ARCHITECTURE.md`
- 指标定义：`METRICS.md`
- 方法审计：[脚本方法审计台账](../../memory/SCRIPT_AUDIT_LEDGER.md)
- 历史代码：`legacy`，不得加入运行路径
