# AD9245 分析程序——先看这里

本目录只需要使用以下六个文件：

- `adc_sfdr_analysis.m`：动态指标
- `adc_bandwidth_analysis.m`：−3 dB 带宽
- `adc_isolation_analysis.m`：通道隔离度

当前 AD9245 批数据的固定条件：刻度扫频为 1 kHz，隔离度为 10 kHz / -6 dB；
隔离度入口的第四个参数可传入 `drivenChannel`，以匹配每个 X1G～X4G
激励目录。
- `adc_power_scale_analysis.m`：输入功率标定
- `adc_inl_dnl_analysis.m`：静态线性度
- `adc_input_noise_analysis.m`：1 Hz 输入等效噪声（AD9245→FPGA×128→JG18 DAC→PICO，直接使用现有刻度）

常规 ADC 项目在 MATLAB 中直接运行后选择数据目录和 CSV 文件即可。直接运行 `adc_input_noise_analysis()` 时，先选择含 `X1G`～`X4G` 子目录的数据根目录，再在列表中勾选本次需要处理的 `G=128` MAT 文件；取消任一选择不会创建结果目录。传入 `dataFolder` 时则保持批处理模式，按标准四路文件名处理。该入口不重新刻度，结果默认保存至所选根目录的 `results/run_时间_项目`；也可显式传入输出目录和运行选项。失败的运行会留下 `STATUS_FAILED.txt`，成功运行会留下 `STATUS_SUCCESS.txt`。

AD9245 的转换时钟为外部注入 20 MHz；但 ILA CSV 每行由 FPGA `clk_25m_cp`（25 MHz，40 ns 间隔）采集。因此 SFDR、带宽、隔离度、功率标定和 INL/DNL 的时间/频率轴均按 25 MHz 处理；20 MHz 作为 ADC 转换时钟记录在运行配置中，不可替代 ILA 记录采样率。

不要修改 `private`，不要把 `legacy` 加入 MATLAB 路径，也不要直接运行 `_shared` 内部函数。问题交接时请同时提供整个运行目录和原始 CSV。

`adc_input_noise_analysis.m` 读取 PicoScope MAT 的 `A/Tinterval`，以 Hann-Welch
PSD/ASD 将 DA9726 JG18 输出端噪声折算到 AD9245 外部板端输入参考面。固定参数为
`G=128`、`k_DAC=1.014514e-4 V/CodePp`；该值直接写入入口配置，本次运行不再查找或核对
DA9726 的 CSV 刻度汇总。默认不扣除 DA/Pico 本底，故数值是总链路输入等效噪声；正式状态仍由原始记录完整性、
参考面和需求证据决定。
