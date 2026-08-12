# AD9245 分析程序——先看这里

本目录只需要使用以下五个文件：

- `adc_sfdr_analysis.m`：动态指标
- `adc_bandwidth_analysis.m`：−3 dB 带宽
- `adc_isolation_analysis.m`：通道隔离度
- `adc_power_scale_analysis.m`：输入功率标定
- `adc_inl_dnl_analysis.m`：静态线性度

在 MATLAB 中直接运行其中一个文件，选择数据目录和 CSV 文件即可。程序会自动使用 AD9245 固定参数，并在 `results/run_时间_项目` 生成结果。取消文件选择不会生成结果目录；失败的运行会留下 `STATUS_FAILED.txt`，成功运行会留下 `STATUS_SUCCESS.txt`。

不要修改 `private`，不要把 `legacy` 加入 MATLAB 路径，也不要直接运行 `_shared` 内部函数。问题交接时请同时提供整个运行目录和原始 CSV。
