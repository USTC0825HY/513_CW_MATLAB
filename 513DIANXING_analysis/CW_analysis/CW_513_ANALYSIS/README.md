# CW_513_ANALYSIS 使用说明

2026-10-12 刻度更新：鉴定件与电性加强件分开配置。2208/677 ILA 与2208/9245/677 PICO噪声交互运行时选择板型，显式传文件时填写 `boardType='jianding'` 或 `'jiaqiang'`。改焊版本默认 `calibrationState='current'`。系数维护位置、完整对照和调用示例见 [刻度配置](CALIBRATION.md)。其他单项分析入口保留原调用方式。

本目录是513/CW电性测试的当前MATLAB分析库，覆盖AD2208、AD9245、AD677、ADC128、DA9726和DA766。正式入口全部是单项分析脚本；运行时只加载本目录的`_shared/+converter`公共内核，不依赖旧`laser_analysis`、旧workflow或归档脚本。

2026-10-02 配置整理：参数在哪里改、怎样单次覆盖、哪些旧字段不生效，见 [参数配置说明](CONFIGURATION.md)；验证证据见 [配置优化报告](docs/20261002_private_config/REPORT.md)。

## 1. 当前可以分析什么

| 器件目录 | 单项入口数 | 当前正式项目 |
|---|---:|---|
| `2208_hy` | 7 | 3 dB带宽、刻度/动态范围、SFDR、ILA噪声、PICO 1 Hz噪声、隔离度、ADC INL/DNL |
| `9245_hy` | 6 | 3 dB带宽、刻度/动态范围、SFDR、PICO 1 Hz噪声、隔离度、ADC INL/DNL |
| `677_hy` | 4 | 3 dB带宽、刻度/动态范围、ILA噪声、PICO 1 Hz噪声 |
| `128_hy` | 1 | 3 dB带宽 |
| `9726_hy` | 4 | 正弦刻度/输出Vpp、直流台阶输出电压、噪声、隔离度 |
| `766_hy` | 4 | 十进制刻度、十六进制刻度/输出Vpp、噪声、隔离度 |

共26个正式入口。9726直流输出电压入口保持原有CSV/PNG/MAT布局；其他入口的统一结果包规则不自动适用于它。DAC INL/DNL、相位噪声和ADC128独立噪声目前没有正式入口，不会用其他指标代替。

## 2. 最简单的运行方式

先进入目标器件目录，再运行需要的单项脚本：

```matlab
cd('你的仓库路径/CW_513_ANALYSIS/2208_hy')
result = adc_sfdr_analysis;
```

零参数运行会弹出文件选择框，只处理本次选择的CSV或MAT。取消选择会正常结束，不创建结果。

不同器件目录中存在同名函数。运行前用下面的命令确认MATLAB实际调用的是当前器件目录：

```matlab
which adc_sfdr_analysis -all
```

如果结果中先出现旧库、发布副本或其他器件目录，请清理MATLAB路径并重新进入目标目录。不要同时把多个器件目录递归加入路径。

当前函数签名、显式调用示例、默认参数和输入要求以各器件README为准。2026-09-20清单保留作为早期版本参考：

- [`docs/20260920_revision/ENTRYPOINTS.md`](docs/20260920_revision/ENTRYPOINTS.md)
- [`docs/20260920_revision/ENTRYPOINTS.csv`](docs/20260920_revision/ENTRYPOINTS.csv)
- 各器件目录中的`README_先看.md`

## 3. ADC十进制和十六进制CSV

读取ADC码值的入口统一支持：

```matlab
runOptions.inputRadix = 'decimal';  % 十进制
runOptions.inputRadix = 'hex';      % 十六进制
runOptions.inputRadix = 'auto';     % 只接受有明确证据的自动判断
```

例如：

```matlab
dataFolder = 'D:/data/AD2208/SFDR';
selectedFiles = {'capture_1MHz.csv'};
outputFolder = 'D:/data/AD2208/SFDR/results';
runOptions = struct('inputRadix', 'hex');

result = adc_sfdr_analysis( ...
    dataFolder, selectedFiles, outputFolder, runOptions);
```

规则如下：

- 支持`0x7FFF`、`7FFF`、`7fff`、`0000`等写法。
- 16位补码按照`7FFF→32767`、`8000→−32768`、`FFFF→−1`转换。
- ADC128继续按照12位unsigned码转换，不套用16位补码。
- 只解析配置指定的ADC数据列；样本号、valid列和其他通道不参与转换。
- 纯数字`1000`可能表示十进制1000或十六进制0x1000，`auto`不会猜测。交互运行会询问；显式运行应指定`hex`或`decimal`。
- 非法字符、混合基数、缺失样点、非整数和超位宽码会报错，不会静默删除。

PICO MAT保存的是电压波形，不使用`inputRadix`。

## 4. 数据如何选择

- ADC带宽、刻度、SFDR、隔离度、INL/DNL和ILA噪声选择原始CSV。
- ADC/DAC PICO噪声、DAC刻度和DAC隔离度选择原始MAT。
- 只选择同一器件、同一接口和同一测量条件的数据；INL/DNL禁止混合接口。
- 不要选择旧`results`或`evidence`中的派生CSV/MAT作为新输入。
- 显式传入文件列表时，脚本不会再弹窗。
- 省略输出目录时，结果通常写入所选数据目录的`results`；少数历史目录布局的准确规则已写入对应器件README。

代码不依赖固定F盘或G盘数据路径。换电脑后直接传入实际数据目录即可，也可把`CW513_DATA_ROOT`环境变量设置为当前数据根目录。

## 5. 参数在哪里修改

参数覆盖优先级为：

1. 本次调用传入的`runOptions`或入口规定的`configOverride`。
2. 器件目录`private/*Config.m`中的当前默认值。
3. `_shared/+converter`公共算法中的通用缺省值。

常改参数优先通过本次调用覆盖，不必修改公共内核。例如：

```matlab
runOptions = struct( ...
    'inputRadix', 'hex', ...
    'sampleRate', 100e6);
```

当前重要默认值：

- 2208 ILA噪声：100 MSPS、131072点、单段Hann、0重叠、NFFT=131072，分辨率762.939453125 Hz。
- ADC PICO 1 Hz噪声：目标分辨率0.2 Hz、Hann、50%重叠；以MAT实际时基为准。
- DA9726/DA766噪声：默认电压增益100；ASD和积分RMS除100，PSD除10000，只补偿一次。
- DAC刻度和DAC隔离度：默认增益1。
- AD9245：当前默认源采样率20 MHz、SFDR步长5、分析采样率4 MHz；历史25 MHz数据必须显式填写历史条件。

详细默认值和字段名以对应`README_先看.md`及`private/*Config.m`为准。

## 6. 结果在哪里

每次成功运行会新建时间戳目录，不覆盖历史结果：

```text
run_时间戳_指标/
  结果汇总.xlsx
  主要结果PNG
  evidence/
    完整数值CSV和PSD/ASD
    参数及run_config.mat
    完整结果MAT
    可编辑FIG
    输入与源码SHA-256
    日志和STATUS
```

日常使用先打开`结果汇总.xlsx`。表中只保留可直接写入测试报告的主要字段；刻度入口同时生成“刻度”和“动态范围”工作表。空白表示未测、覆盖不足或不可计算，不表示0，也不表示合格。

`evidence`用于复核算法、追溯输入和重新生成图表。实际采用的进制、数据列、位宽和转换规则记录在`evidence/input_decoding.csv`。

## 7. 计算和判定边界

- ADC刻度使用`Vpp = k×CodePp + b`。
- 动态范围中的99%临界输入可能来自扫描范围外外推；工作簿和图片会明确标为“非实测”。
- SFDR使用单边谱和互斥排除区；THD按`10log10(P谐波/P基波)`输出，通常为负数。
- 带宽默认全部选中点参与−3 dB交点；达到/超过Nyquist的点仅以`NyquistOrAboveFlag`标注、不剔除，除非器件显式配置`rejectNyquistOrAbove=true`。削顶、病态拟合、拟合幅值超码域或R²不足的点不参与交点，全部频点明细仍保存在evidence。
- ADC INL/DNL为正弦码密度和best-fit定义；部分码域不能作为全码域结论。
- PICO 1 Hz输入等效噪声是整条采集链折算值，当前不扣除PICO、DAC和前级本底。
- 隔离度必须确认驱动端、受扰端、测试频率、通道增益和参考面。
- 没有配置正式限值或测量条件不完整时，结果保持“暂不能判定”。成功生成图片不等于方法或器件指标已经验证。

## 8. 目录结构

```text
CW_513_ANALYSIS/
  128_hy/ 2208_hy/ 677_hy/ 9245_hy/ 9726_hy/ 766_hy/
  _shared/+converter/       公共读取、算法、报告和运行内核
  noise_chain_hy/           ADC—FPGA—DA9726—PICO联合噪声链
  tests/                    单元、集成和黄金回归
  tools/                    维护及发布工具，不是日常分析入口
  docs/20260920_revision/   审计报告、入口清单和脚本矩阵
  ARCHITECTURE.md           依赖和运行结构
  METRICS.md                指标公式与适用边界
  CALIBRATION.md            随代码维护的刻度说明
```

历史`legacy`和旧`_release`已移出日常运行区。不要把旧发布包、旧快照和当前主库同时加入MATLAB路径。

## 9. 测试与当前验证状态

2026-10-12刻度修订：55条报告刻度核对通过；分批汇总228个不同测试的最近一次结果全部通过，最后两批30/30、13/13。包含板型、版本、取消、来源冲突、噪声比例及输出来源检查。详见[实施报告](docs/20261012_board_calibration/REPORT.md)和[回归清单](docs/20261012_board_calibration/regression_latest.csv)。本轮使用合成/夹具数据，历史大型实测批次未全面重算。2026-10-13仅更新说明并上传代码。

以下为2026-09-20历史验证记录：

- 144个MATLAB脚本清单和SHA-256核对。
- 十六进制边界、纯数字歧义、非法输入、valid抽取和所选数据列测试。
- 精简XLSX字段、数值类型和evidence布局测试。
- 噪声100倍增益、PICO变量、压缩MAT、带宽门控、隔离度及INL/DNL状态测试。
- AD677 X3十进制/十六进制真实等价复算。
- DA9726真实刻度复算。

AD9245旧黄金数据的四个入口已经按历史25 MHz条件实际运行，但当前新增的方法状态和字段与重构前黄金CSV签名不同，因此记录为`GoldenMismatch`；旧黄金基线没有被改写。

完整结论和未覆盖项见：

- [`docs/20260920_revision/AUDIT_REPORT.md`](docs/20260920_revision/AUDIT_REPORT.md)
- [`docs/20260920_revision/SCRIPT_MATRIX.csv`](docs/20260920_revision/SCRIPT_MATRIX.csv)
- [`docs/20260920_revision/REDUNDANCY.md`](docs/20260920_revision/REDUNDANCY.md)

## 10. 开始逐项测试

建议按以下顺序操作：

1. 进入目标器件目录。
2. 打开该目录的`README_先看.md`，确认当前采样率、增益和接口映射。
3. 运行单项入口并选择原始文件。
4. 对纯数字码值显式设置`inputRadix`。
5. 打开新结果目录中的`结果汇总.xlsx`。
6. 需要复核时查看`evidence/run_config.mat`、完整CSV、输入哈希和STATUS。
7. 将参考面、端接、增益和仪器条件补入测试记录后，再判断能否形成正式结论。

## 11. 两套板型刻度如何选择

零参数运行2208/677 ILA、2208/9245/677 PICO噪声时，按窗口选择板型。显式文件调用在原有runOptions/configOverride中设置板型，例如在2208_hy：

```matlab
options = struct('boardType','jianding', ...
    'calibrationState','current','inputRadix','decimal');
result = adc_ila_noise_analysis(dataFolder,selectedFiles,outputFolder,options);
```

加强件改为`jiaqiang`。`current`优先改焊后，否则采用唯一记录并保留其原状态；`before`/`after`要求对应版本确实存在。9245 PICO仍是三参数调用，选项放第三参数。

长期系数集中维护在[`report_calibrations_20261004.csv`](_shared/+converter/+calibration/report_calibrations_20261004.csv)，共55条。PICO同步选择同板DA9726 JG18。自定义刻度、工作簿及来源冲突规则见[CALIBRATION.md](CALIBRATION.md)。

结果汇总.xlsx上方显示板型和版本；evidence保存实际系数、报告哈希及表格定位。切换板型后重算噪声会相应变化。DAC电压噪声、扫描刻度拟合及不使用电压刻度的指标保留原计算方式。
