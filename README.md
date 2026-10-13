# 513 CW MATLAB 数据分析库

本仓库保存513/CW电性测试的MATLAB分析代码。当前维护入口位于：

[`513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS`](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS)

该分析库覆盖AD2208、AD9245、AD677、ADC128、DA9726和DA766，共26个单项分析入口。原始测试数据和运行结果不进入Git；代码、配置、测试、审计清单和可复现说明保存在仓库内。

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

每次成功运行会生成时间戳结果目录。DA9726直流台阶输出电压入口保留CSV/PNG/MAT布局；其余入口采用下述汇总布局。日常查看根目录的`结果汇总.xlsx`和主要PNG；完整CSV、MAT、FIG、配置、输入/源码哈希、日志和状态位于`evidence/`。

## 文档入口

- [分析库使用说明](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/README.md)
- [早期入口调用清单（2026-09-20）](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20260920_revision/ENTRYPOINTS.md)
- [计算方法和验证报告](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20260920_revision/AUDIT_REPORT.md)
- [完整脚本矩阵](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20260920_revision/SCRIPT_MATRIX.csv)
- [架构说明](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/ARCHITECTURE.md)
- [指标定义](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/METRICS.md)

## 仓库边界

- `513DIANXING_analysis`：513测试分析源码、配置、测试和项目记忆。
- `laser_analysis`：早期公共分析代码；当前26个入口不依赖它。
- `legacy`：历史代码，只用于追溯，不应加入日常MATLAB路径。
- `catalog`、`tools`：迁移清单和仓库级维护工具。

方法测试通过不等于器件性能通过。正式结论仍需要真实采集条件、参考面、增益、负载、限值和原始数据共同支持。

## 2026-10-13 当前版本使用要点

鉴定件和电性加强件的刻度分别维护。2208/677 ILA及2208/9245/677 PICO噪声交互运行时选择板型；显式文件调用需在原有选项结构中加入：

```matlab
options = struct('boardType','jianding','calibrationState','current', ...
    'inputRadix','decimal');
% 在2208_hy运行；进制按实际CSV选择decimal或hex
result = adc_ila_noise_analysis(dataFolder,selectedFiles,outputFolder,options);
```

加强件使用`boardType='jiaqiang'`。`current`优先使用改焊后，否则采用唯一记录；`before`和`after`显式选择历史版本。PICO使用同板型DA9726 JG18刻度。每次运行独立选择，完整来源写入evidence。

- [刻度维护、版本选择及自定义刻度](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/CALIBRATION.md)
- [参数配置和覆盖规则](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/CONFIGURATION.md)
- [2026-10-12刻度修订与验证](513DIANXING_analysis/CW_analysis/CW_513_ANALYSIS/docs/20261012_board_calibration/REPORT.md)

当前26个入口以各器件README及源码签名为准。2026-10-12回归分批汇总228个不同测试的最近一次结果全部通过，最后两批30/30、13/13；55条报告刻度逐行核对通过。本次README更新未重新执行数值回归；历史大批数据未按新刻度全面重算。
