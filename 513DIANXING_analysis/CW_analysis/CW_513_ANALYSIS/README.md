# CW_513_ANALYSIS 513测试器件分析库

本库用于513测试中的五类器件：AD9245、AD2208、AD677、DA9726和DA766。器件入口、公共算法、测试和发布工具全部位于本目录内，运行器件入口不依赖 `laser_analysis`、`01_workflows`或历史脚本。

当前常用数据根目录为：

`F:\01_Laser\0_20260727_513test\CW_Data\513_CW_DATA`

本机 DA9726 噪声采集还位于：

`G:\513_CW_test\CW_Data\513_CW_DATA\DA9726\03_Noise\nosie_20260901`

两个路径都不是代码仓库。换电脑时请把实际数据目录作为入口参数传入；也可以设置环境变量 `CW513_DATA_ROOT`，其值应为包含 `DA9726` 的数据根目录。代码不会把 F 盘不存在的旧目录当作有效数据目录。

使用说明见各器件目录的 `README_先看.md`；公共结构和指标说明见 `ARCHITECTURE.md`、`METRICS.md`。

## 器件入口

新增 `128_hy`：ADC128的12 bit unsigned CSV带宽入口，支持全正正弦。采样率须按本次记录填写，调用见 `128_hy/README_先看.md`；尚未注册独立发布包。下列五类原有器件入口保持不变。

- `9245_hy`：SFDR、带宽、隔离度、`CodePp -> Vpp` 刻度及99%临界输入估计、INL/DNL，以及经 DA9726 JG18/G=128 链路折算的 1 Hz 输入等效噪声。
- `2208_hy`：SFDR、带宽、隔离度、`CodePp -> Vpp` 刻度及99%临界输入估计、INL/DNL；`adc_ila_noise_analysis` 处理直接 ILA 噪声，`adc_pico_noise_1hz_analysis` 处理经 DA9726 刻度折算的 PICO 1 Hz 噪声。
- `677_hy`：输入频率响应、输入 Vpp—CodePp 刻度及99%临界输入外推；另有直接ILA噪声和经DA9726 JG18/G=128链路折算的PICO 1 Hz输入等效噪声。正式结论暂关闭。
- `9726_hy`：DA刻度、DA噪声、DA隔离度；刻度和噪声入口相互独立，多通道PICO隔离度MAT可先按文件名接口顺序切成单通道派生MAT，隔离度结果同时导出 dB 矩阵 CSV 和矩阵热力图。
- `766_hy`：DA刻度、DA噪声、DA隔离度。

DA刻度入口给出正弦输出 Vpp；独立DC输出电压、DAC INL/DNL、DA相噪以及DA766更新率/分辨率暂没有对应正式入口。DA9726/DA766 当前入口的 `formalEnabled` 保持关闭，结果可用于迁移和复核，但不自动给出正式满足结论。

五个目录共25个单项入口，文件选择方式如下：零参数选择本次原始文件；只给目录、文件留空时也弹文件选择框；取消正常退出，不生成结果。CSV项目选CSV，PICO/DAC项目选MAT；显式非空文件列表或配对清单不弹窗。2208和677的ILA入口不自动处理固定文件，INL/677/DAC入口不默认处理整目录。DA9726隔离度先单选驱动MAT，再一次多选全部受扰MAT，不再要求重复填写接口、变量、频率和增益；多通道MAT可先运行 `split_dac_isolation_channels`。DA766保留原有逐对流程。9245 PICO逐份选择接口，677 PICO显式运行时必须指定接口。函数签名见各器件 `README_先看.md`。

省略输出目录时，输入为raw目录则写其同级results，其他目录写其内部results；677保留raw下采集子目录写到raw同级results的布局。2208 PICO保留所选目录内部results规则。每次新建时间戳子目录，同秒追加序号，历史结果保留。9245 PICO的第二参数仍是输出目录；DAC隔离度的第二参数仍是配对清单。不要把普通波形列表传作配对清单。

2208 ILA自2026-09-08起使用1段、0重叠、NFFT=131072。100MHz/131072有效点对应整段一次计算、频点间隔762.939453125Hz；固定单段模式拒绝其他记录长度。PICO噪声的0.2Hz/50%重叠设置保持独立。

AD9245旧ILA数据为25 MHz，后续计划改用20 MHz采集。当前MATLAB默认仍是25 MHz；分析新数据前需按实际采集设置调整，旧数据不能改用20 MHz。具体参数见 `9245_hy/README_先看.md`。PICO噪声读取MAT时基，不使用ILA采样率。

## 独立运行

开发模式下，入口只加载相邻的 `_shared/+converter`。发布模式下，`tools/buildDeviceRelease.m` 将公共内核复制到器件包的 `internal/+converter`，器件包可以脱离本目录、`laser_analysis`和原workflow迁移运行。

上面的独立发布说明针对已注册的常规入口。2208/9245/677 PICO联合噪声还依赖
相邻 `noise_chain_hy`，当前发布注册表未包含这些噪声入口，已有发布包未随入口修改更新。
运行PICO噪声分析时，需要保留主库依赖，不能只复制器件文件夹。

## 维护入口

- 公共算法和运行时：`_shared/+converter`
- 自动化测试：`tests/run_all_tests.m`
- 独立交付包：`tools/buildDeviceRelease.m`
- 架构规则：`ARCHITECTURE.md`
- 指标定义：`METRICS.md`
- 历史代码：legacy（已归档至 F:\01_Laser\research_assets\CW_513_ANALYSIS_archive\20260908\legacy），不得加入运行路径

## 刻度配置

20260903报告中的20条刻度已随代码发布，见 [CALIBRATION.md](CALIBRATION.md)。AD2208 ILA及2208/9245 PICO噪声默认使用报告中的新ADC刻度，不再依赖外部ADC刻度工作簿；旧工作簿只能通过参数显式指定。报告文件和私人维护文件不需要复制到新电脑。
