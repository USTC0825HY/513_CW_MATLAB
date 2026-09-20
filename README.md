# 513 CW MATLAB 数据分析库

本仓库保存513/CW电性测试的MATLAB分析代码。当前维护入口位于：

[`513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS`](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS)

该分析库覆盖AD2208、AD9245、AD677、ADC128、DA9726和DA766，共25个单项分析入口。原始测试数据和运行结果不进入Git；代码、配置、测试、审计清单和可复现说明保存在仓库内。

## 快速开始

```matlab
cd('你的仓库路径/513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/2208_hy')
result = adc_sfdr_analysis;
```

零参数运行时选择本次要处理的CSV或MAT文件。不同器件目录存在同名入口，运行前先进入目标器件目录，并检查：

```matlab
which adc_sfdr_analysis -all
```

ADC码值CSV支持十进制和十六进制。纯数字码值存在进制歧义时，请显式传入：

```matlab
runOptions = struct('inputRadix', 'hex');   % 或 'decimal'
result = adc_sfdr_analysis(dataFolder, selectedFiles, outputFolder, runOptions);
```

每次成功运行会生成时间戳结果目录。日常查看根目录的`结果汇总.xlsx`和主要PNG；完整CSV、MAT、FIG、配置、输入/源码哈希、日志和状态位于`evidence/`。

## 文档入口

- [分析库使用说明](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/README.md)
- [25个入口准确调用命令](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20260920_revision/ENTRYPOINTS.md)
- [计算方法和验证报告](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20260920_revision/AUDIT_REPORT.md)
- [完整脚本矩阵](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20260920_revision/SCRIPT_MATRIX.csv)
- [架构说明](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/ARCHITECTURE.md)
- [指标定义](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/METRICS.md)

## 仓库边界

- `513DIANXING_analysis`：513测试分析源码、配置、测试和项目记忆。
- `laser_analysis`：早期公共分析代码；当前25个入口不依赖它。
- `legacy`：历史代码，只用于追溯，不应加入日常MATLAB路径。
- `catalog`、`tools`：迁移清单和仓库级维护工具。

方法测试通过不等于器件性能通过。正式结论仍需要真实采集条件、参考面、增益、负载、限值和原始数据共同支持。
