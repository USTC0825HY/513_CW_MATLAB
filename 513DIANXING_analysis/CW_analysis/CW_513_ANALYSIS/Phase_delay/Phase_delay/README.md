# 幅频、相频与延迟分析

本目录已包含转换后的 `JG22-jg18.mat`。在 MATLAB 中运行 `run_JG22_JG18`，即可重现真实数据的幅频/相频图、阈值延迟图及校正结果。幅值与相位使用同一坐标图的左右双纵轴，原始和校正图均如此。

当前计算采用 A（通道 1）为输入、B（通道 2）为输出：A 先跳变、B 后响应。采样间隔 0.4 ns；全记录首尾各 15% 作为平台估计，无平滑；10% 延迟约 246.62 ns，50% 延迟约 262.36 ns。通道方向仍须与实际接线一致。

## 1. psdata 转 MAT

`psdata_to_mat.py` 使用 Python 标准库调用官方转换程序，支持 PicoScope 6 和具备 BatchConvert 功能的 PicoScope 7。它不是免安装的独立解码器。每次建立独立输出目录，保留源文件副本、转换日志和清单，不覆盖原始数据。

安装官方软件后，在本目录终端运行：

```powershell
python psdata_to_mat.py --check
python psdata_to_mat.py JG22-jg18.psdata
# 非默认安装位置：
python psdata_to_mat.py JG22-jg18.psdata --picoscope "D:\YourPath\PicoScope.exe" --version 7
```

输出在 `converted/conversion_时间_随机编号/mat/`。多条波形可能输出多个文件，应选择同一记录内含输入、输出通道的 MAT 做分析。MAT 文件生成后由 MATLAB 读取并校验；转换进程成功不等于波形物理信息已验证。旧版 PicoScope 7 不一定具备 BatchConvert，失败时查看日志或从软件中另存为 MAT。

依据：[官方专有格式说明](https://www.picotech.com/support/viewtopic.php?t=38741)、[PicoScope 7 转换命令](https://www.picotech.com/support/viewtopic.php?t=43252)、[PicoScope 6 转换命令](https://manuals.picotech.com/picoscope6/en/commandlinesyntax.html)、[软件下载](https://www.picotech.com/downloads)。

## 2. MATLAB 分析

把 MATLAB 当前目录切换到本目录：

```matlab
% 无示波器数据时也能输出真实 Bode 图与数据：
r = analyze_phase_delay;

% 将路径换成上一步生成的文件。默认 A 为输入、B 为输出，必须按接线确认。
r = analyze_phase_delay(ScopeFile="converted/实际转换目录/mat/实际文件.mat", ...
    InputChannel="A", OutputChannel="B");

% 有多个脉冲时，选择一个边沿，前后都保留稳定平台；单位为秒：
% r = analyze_phase_delay(ScopeFile="capture.mat",TimeWindow=[-100e-9 500e-9]);
```

本次已读取 MAT 确认通道变量为 A、B。按波形先后顺序采用 A 输入、B 输出；如实际接线不同，修改 InputChannel、OutputChannel 参数。

支持 PicoScope CSV 的 `Time,Channel A,Channel B` 表头以及下一行 `(ns),(V),(V)` 单位。时间单位支持 s/ms/us/ns/ps；识别失败可设置 `TimeUnit="ns"`。MAT 使用官方 Tstart/Tinterval 秒单位。每个 MAT 仅接受单条波形的通道向量。

## 3. 方法和输出

- Bode CSV：按表头读取频率、幅值 dB、相位 deg，保留原文件已展开的相位。仅当所有相位落在 ±180° 内时尝试展开；稀疏频点下的真实相位圈数仍有歧义。
- 阈值：选定窗口的首尾各 15% 样本中位数作为边沿前后平台，每个通道分别归一化。10%/50% 是各自幅度变化的百分比，不是两个通道共用电压值。支持上升、下降和反相。
- 时间：阈值相邻采样点线性插值，延迟 = 输出到达时刻 − 输入到达时刻。窗口须只有一个明确 50% 过阈值边沿；10% 取其前最后一次过阈值，降低早期噪声误选。异常或多边沿会报错；先设置合适 TimeWindow。必要时可设置奇数 `SmoothSamples` 做中值平滑，默认 1 不平滑；平滑会影响时间估计。
- 相位：`phi_corrected = phi_measured + 360*f*tau`。分别输出 10% 与 50% 结果，幅值不因理想纯延迟扣除而改变。
- `results/bode_response.png/.fig/.csv`：原始幅频/相频。
- `results/scope_delay.png/.fig`：完整波形、选定边沿归一化阈值图、延迟比较图。
- `results/delay_summary.csv`：阈值时刻与延迟（秒及 ns）。
- `results/phase_corrected.png/.fig`：幅频与原始/两种校正相频在同一双纵轴图中。`phase_corrected.csv` 另含两种被扣除的纯延迟相位列。
- `results/analysis.mat`：完整结果、选定窗口及参数。

重要物理限制：阈值延迟包含滤波器对边沿形状的影响，并不天然等于纯传输延迟。两种校正只是把测得延迟等效为常数纯延迟后的结果。探头/电缆的通道偏斜也计入测量值，应使用已校准且与 Bode 测量一致的参考面。插值增加时间分辨率，但不代表亚采样间隔的测量准确度。

## 4. 验证

运行 `test_phase_delay`，使用单独 `test_results/` 中的合成波形验证已知 37 ns 延迟、极性反转、不同上升时间导致 10%/50% 延迟不同、异常边沿拒绝、CSV/MAT 时间单位，以及真实 Bode 文件相位连续性和校正符号。`test_results` 所有延迟及校正结果仅为测试，不能用于描述本设备。
