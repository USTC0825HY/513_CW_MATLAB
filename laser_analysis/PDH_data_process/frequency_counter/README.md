# 频率计数器数据分析

本目录用于分析 PDH 锁定实验中的频率计数器数据，当前程序为：

- `plot_allen_with_freq_counter.ipynb`

程序支持 K+K 多通道频率计数器和 Keysight 单通道频率计数器数据，可进行时域分析、线性漂移去除、Modified Allan deviation（MDEV）计算和频率噪声幅度谱密度分析。

## 1. 环境依赖

程序使用 Python 3，主要依赖：

```text
numpy
matplotlib
scipy
allantools
```

在 Jupyter Notebook 中按顺序运行所有单元即可。Notebook 可从工程根目录或 `frequency_counter` 目录启动。

## 2. 数据目录

原始测量数据放在：

```text
frequency_counter/data/
```

`data` 目录已通过工程根目录的 `.gitignore` 排除，原始测量数据不会提交到 Git。

### 2.1 K+K 多通道数据

当前程序假定 K+K 文本数据的列结构为：

```text
日期  时间  状态/同步标志  通道1频率  通道2频率  ...
```

前三列不是频率通道；从第 4 列开始依次对应 K+K 通道 1、通道 2 等。配置中的通道号从 1 开始，而不是使用 NumPy 的零起始列号。

例如，只分析通道 1：

```python
{
    'file': DATA_DIR / 'your_kk_data.txt',
    'format': 'kk',
    'channels': [1],
    'label': 'K+K',
    'colors': ['#880000'],
    'tau': 0.01,
}
```

同时分析并绘制通道 1 和通道 2：

```python
'channels': [1, 2]
```

可以继续增加通道号，但不能超过文件中实际包含的频率通道数量。每个指定通道会被独立处理和绘图。

### 2.2 Keysight 单通道数据

对于每行只有一个频率值的文件，使用：

```python
{
    'file': DATA_DIR / 'your_keysight_data.csv',
    'format': 'single',
    'label': 'Keysight',
    'colors': ['#228833'],
    'tau': 0.01,
}
```

如果文件包含多列，可以用从 1 开始的 `column` 指定频率所在列：

```python
'column': 2
```

## 3. 主要配置参数

每份数据通过 `data_configs` 中的一个字典配置：

| 参数 | 含义 |
|---|---|
| `enabled` | 是否分析该数据，设为 `False` 可临时跳过 |
| `file` | 数据文件的绝对路径；若文件夹和文件名分开保存，需在调用单元中先拼接 |
| `format` | `kk` 或 `single` |
| `channels` | K+K 要分析的通道列表，通道号从 1 开始 |
| `column` | `single` 多列文件中的频率列，列号从 1 开始 |
| `label` | 图例和输出中使用的名称 |
| `colors` | 各通道的绘图颜色 |
| `tau` | 相邻频率样本的采样间隔，单位为秒 |
| `cut_ratio_lower` | 保留数据的起始比例，范围为 0 到 1 |
| `cut_ratio_upper` | 保留数据的结束比例，范围为 0 到 1 |
| `psd_nperseg` | Welch 频谱计算中每段的数据点数 |

例如，只分析整段数据的 10% 到 80%：

```python
'cut_ratio_lower': 0.1,
'cut_ratio_upper': 0.8,
```

`tau` 必须使用计数器实际设置的采样间隔。例如采样率为 100 Hz 时：

```python
'tau': 0.01
```

## 4. 一键运行分析

完整的读取、逐通道计算和绘图流程已经封装为：

```python
run_frequency_counter_analysis(
    data_configs,
    plot_title,
    optical_reference_hz=None,
    wavelength_nm=None,
    deviation_type='mdev',
    show_plots=True,
)
```

Notebook 首先自动定位自身所在的 `frequency_counter` 目录。Jupyter Notebook 没有稳定可用的
`__file__`，因此程序会从当前工作目录逐级向上查找
`plot_allen_with_freq_counter.ipynb`。从工程根目录或 `frequency_counter`
目录启动 Jupyter 均可正常定位：

```python
SCRIPT_DIR = detect_notebook_directory()
SYNC_ROOT = find_parent_directory(SCRIPT_DIR, 'USL_DLOCK')
FREQUENCY_COUNTER_DATA_ROOT = (
    SYNC_ROOT / '1.Data' / '杨正光上传' / '拍频数据' / '频率计数器'
)
```

这样同步盘在不同设备上使用不同盘符或用户目录时，只要 `USL_DLOCK`
内部的相对位置不变，就不需要修改绝对路径前缀。

分析新文件时，只需要在调用单元中设置数据目录，将目录与文件名拼成完整路径，然后调用一次函数：

```python
DATA_DIR = (SCRIPT_DIR / 'data').resolve()
wavelength_nm = 1397.0
optical_reference_hz = 299792458.0 / (wavelength_nm * 1e-9)
plot_title = 'DX1 Si3 beat'
deviation_type = 'mdev'  # 可选 'adev' 或 'mdev'

data_configs = [
    {
        'file': DATA_DIR / 'your_kk_data.txt',
        'format': 'kk',
        'channels': [1, 2],
        'label': 'K+K',
        'colors': ['#880000', '#004488'],
        'tau': 0.01,
        'cut_ratio_lower': 0.0,
        'cut_ratio_upper': 1.0,
        'psd_nperseg': 4096,
    },
]

results = run_frequency_counter_analysis(
    data_configs=data_configs,
    plot_title=plot_title,
    optical_reference_hz=optical_reference_hz,
    wavelength_nm=wavelength_nm,
    deviation_type=deviation_type,
)
```

`run_frequency_counter_analysis()` 的入口不再接收 `data_dir`。每个
`config['file']` 必须是完整的绝对路径；保留“文件夹 + 文件名”两个变量时，
在调用单元中使用 `DATA_DIR / '文件名.txt'` 完成拼接。这样同一次分析可直接比较不同文件夹的数据：

```python
data_configs = [
    {'file': DATA_DIR_A / 'file_a.txt', ...},
    {'file': DATA_DIR_B / 'file_b.txt', ...},
]
```

函数会检查路径是否为绝对路径、文件是否存在，并且不会修改传入的 `data_configs`。

`optical_reference_hz` 和 `wavelength_nm` 可以只提供其中一个：

- 只提供 `wavelength_nm` 时，函数自动计算 `c / wavelength`；
- 同时提供两者时，函数会检查二者是否一致；
- 如果只想计算而暂时不显示图形，可设置 `show_plots=False`。

`deviation_type` 用于选择稳定度统计量：

```python
deviation_type = 'adev'  # Allan deviation
deviation_type = 'mdev'  # Modified Allan deviation（默认）
```

同一次对比分析中的所有数据统一使用所选类型。程序会同步修改计算方法、图标题、纵坐标、终端输出和 legend 中的 1 s 稳定度名称。

函数返回完整的 `results` 列表，便于后续访问 MDEV、ASD 和处理后的时域数据。

## 5. 分析内容

### 5.1 时域频率

对每个通道绘制：

1. 原始频率数据和线性漂移拟合；
2. 减去线性漂移后的频率偏差。

线性漂移通过一次多项式拟合得到。频率阶跃、失锁或重新锁定不是线性漂移，不能依靠该步骤消除。包含这些事件的数据应先选择稳定区间，再计算稳定度和噪声谱。

### 5.2 Allan deviation 与 Modified Allan deviation

程序根据 `deviation_type` 使用 `allantools.adev` 计算 Allan deviation，或使用 `allantools.mdev` 计算 Modified Allan deviation：

```python
allantools.adev(...)  # deviation_type = 'adev'
allantools.mdev(
    y_data,
    rate=1.0 / tau,
    data_type='freq',
    taus='decade',
)
```

其中相对频率波动按照光学参考频率归一化：

```text
y(t) = Δf(t) / f_optical
f_optical = c / λ
```

当前 Notebook 中的默认波长为 `1397 nm`。如果实验波长不同，应修改：

```python
wavelength_nm = 1397.0
```

图中同时保留原始数据和线性去漂数据的 ADEV 或 MDEV。程序会在终端输出最接近 1 s 平均时间的去漂稳定度，并在对应去漂曲线的 legend 中显示，例如：

```text
20260715 beat-1 (detrended, 1 s MDEV=1.00e-15)
```

稳定度图只在实际 1 s 数据点处保留圆点标记，不在曲线附近绘制文字或箭头，因此多组秒稳数值接近时不会发生标注重叠。

两种配置对应的纵坐标分别为：

```text
adev: Allan deviation σ_y(τ)
mdev: Modified Allan deviation σ_y^mod(τ)
```

这里绘制的是 deviation（标准差形式），不是将其平方后的 variance。实验中常把 Allan deviation 口头简称为“艾伦方差”，引用结果时建议明确写 ADEV 或 MDEV。

需要注意：

- MDEV 与普通 Allan deviation（ADEV）不是同一个统计量；
- 拍频结果表示两路信号的差分稳定度；
- 只有在两台激光噪声相同且互不相关时，才可将拍频稳定度除以 `sqrt(2)` 估计单台激光稳定度；
- 线性去漂会影响较长平均时间处的结果，因此原始曲线和去漂曲线都应保留。

### 5.3 频率噪声幅度谱密度

程序对线性去漂后的频率数据使用 Welch 方法估计频率噪声功率谱密度，然后取平方根得到幅度谱密度（ASD）：

```text
ASD(f) = sqrt(PSD(f))
```

绘图单位为：

```text
Hz/sqrt(Hz)
```

严格来说：

- 功率谱密度 PSD 的单位为 `Hz^2/Hz`；
- 幅度谱密度 ASD 的单位为 `Hz/sqrt(Hz)`。

`psd_nperseg` 越大，频率分辨率越高，但可用于平均的 Welch 数据段越少。对于 100 Hz 采样率和当前长度的数据，默认值为：

```python
'psd_nperseg': 4096
```

此时频谱范围约为 `0.024 Hz` 到奈奎斯特频率 `50 Hz`。

## 6. 输出图形

程序运行后会生成：

1. 每个通道的原始频率、漂移拟合和去漂频率图；
2. 所有数据通道的 ADEV 或 MDEV 对比图，去漂曲线的 legend 同时给出 1 s 稳定度；
3. 所有数据通道的频率噪声 ASD 对比图。

分析结果同时保存在 Notebook 中的 `results` 列表。每个元素包含：

```text
label
channel
config
processed
deviation
deviation_type
adev 或 mdev（与本次配置对应的兼容别名）
asd
```

可通过这些数据继续进行拟合、导出或定制绘图。

## 7. 数据检查建议

正式引用分析结果前，建议检查：

- 文件格式和通道编号是否正确；
- `tau` 是否与计数器采样设置一致；
- 所选数据区间内是否存在失锁、频率阶跃或重新锁定；
- K+K 各通道是否均为有效测量信号；
- 光学参考波长是否正确；
- 实验需要的是 MDEV、ADEV，还是其他稳定度统计量；
- 频谱中的窄峰是否来自电源、机械振动或采样系统。

对于明显无效、饱和或跳变的通道，不应仅依靠线性去漂后直接计算稳定度。
