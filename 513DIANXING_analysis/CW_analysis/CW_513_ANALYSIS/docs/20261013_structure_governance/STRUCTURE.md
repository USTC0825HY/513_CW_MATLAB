# 当前源码结构（2026-10-13）

以磁盘源码为准；正式入口26个，辅助脚本单独计数。完整签名与哈希见[SOURCE_STRUCTURE.csv](SOURCE_STRUCTURE.csv)。

| 分类 | 文件数 |
|---|---:|
| FFT辅助 | 2 |
| Phase_delay辅助代码 | 19 |
| private配置/辅助 | 16 |
| 公共内核 | 77 |
| 切分工具 | 2 |
| 审计工具 | 1 |
| 批处理 | 1 |
| 正式单项入口 | 26 |
| 测试 | 28 |
| 维护/发布工具 | 6 |
| 联合噪声公共入口 | 1 |

## 正式单项入口

| 器件 | 入口 |
|---|---|
| 128_hy | `adc_bandwidth_analysis.m` |
| 2208_hy | `adc_bandwidth_analysis.m` |
| 2208_hy | `adc_ila_noise_analysis.m` |
| 2208_hy | `adc_inl_dnl_analysis.m` |
| 2208_hy | `adc_isolation_analysis.m` |
| 2208_hy | `adc_pico_noise_1hz_analysis.m` |
| 2208_hy | `adc_power_scale_analysis.m` |
| 2208_hy | `adc_sfdr_analysis.m` |
| 677_hy | `adc_bandwidth_analysis.m` |
| 677_hy | `adc_ila_noise_analysis.m` |
| 677_hy | `adc_pico_noise_1hz_analysis.m` |
| 677_hy | `adc_power_scale_analysis.m` |
| 766_hy | `dac_isolation_analysis.m` |
| 766_hy | `dac_noise_analysis.m` |
| 766_hy | `dac_scale_analysis.m` |
| 766_hy | `dac_scale_hex_analysis.m` |
| 9245_hy | `adc_bandwidth_analysis.m` |
| 9245_hy | `adc_inl_dnl_analysis.m` |
| 9245_hy | `adc_input_noise_analysis.m` |
| 9245_hy | `adc_isolation_analysis.m` |
| 9245_hy | `adc_power_scale_analysis.m` |
| 9245_hy | `adc_sfdr_analysis.m` |
| 9726_hy | `dac_isolation_analysis.m` |
| 9726_hy | `dac_noise_analysis.m` |
| 9726_hy | `dac_output_voltage_analysis.m` |
| 9726_hy | `dac_scale_analysis.m` |

## 调用与维护关系

器件入口读取private配置，经参数覆盖和校验调用_shared/+converter；PICO联合噪声还调用noise_chain_hy。公共刻度在需要电压换算时由calibration模块选择，避免配置初始化提前加载板型。

677目录包含4个正式入口和4个审计/批处理/FFT辅助脚本；9726目录包含4个正式入口和1个切分工具。Phase_delay及tools维护工具单独管理，目录中.m数量不等于正式入口数。

同名函数按当前器件目录选择，用which检查；不对整个库执行addpath(genpath(...))。9245 PICO保留三参数，766十六进制刻度第四参数为频率数值；2208 INL按原五参数签名，详见各器件README。

本清单仅记录软件结构；2026-10-12回归与报告刻度核对的证据见[刻度修订报告](../20261012_board_calibration/REPORT.md)。本轮没有执行新的指标数值回归。
