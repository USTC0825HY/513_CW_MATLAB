# 可视化分析平台的 MATLAB 桥

此目录把现有 26 个单项入口提供给独立分析窗口。计算继续使用原来的入口和公共内核，平台读取保存的结果表和 FIG 数值供交互显示；不需要采集设备连接。

## 启动与配置

MATLAB R2025b 已用于本轮验证。仍需要相应分析原有的工具箱。Python 通过独立 MATLAB batch 进程调用：

```matlab
addpath('库目录/tools/platform');
cw513_platform('任务目录/request.json','任务目录/response.json');
```

`catalog.json` 仅保存入口、调用形式及接口清单。`defaults` 调用器件目录中的 `cw513_*_config.m`，由它读取原 private 配置，没有第二份默认数值。薄适配器属于平台依赖，不计入 26 个正式入口。

`defaults` 的 `fields` 提供名称、中文标签、单位、类型、可编辑状态和当前值。`config` 是完整来源配置。界面只提交实际改动字段；不要将整份默认快照重新提交，尤其是自动推导使用的 `NaN`。JSON 中该值为 `null`，对应字段另外记录 `nonfinite: "NaN"`。

## JSON 请求

```json
{
  "schema_version": 1,
  "action": "run",
  "entry_id": "ad2208.ila_noise",
  "data_folder": "F:/captures",
  "selected_files": ["ADC1_JG15.csv"],
  "output_folder": "F:/derived/task_001",
  "options": {
    "boardType": "jianding",
    "inputRadix": "decimal",
    "inputChannels": ["ADC1_JG15"]
  }
}
```

- `action`：`catalog`、`defaults`、`preview`、`run`。
- `entry_id`：见 `catalog.json`，例如 `da9726.noise`。
- `selected_files`：明确选择的 CSV/MAT。可以使用绝对路径；相对路径以 `data_folder` 为基准。
- `options`：保持原 MATLAB 参数名称。未知字段和平台管理字段直接报错。板型、进制、通道、采样率和增益按实际采集条件填写。
- `output_folder`：正式运行必填。每次由原入口生成新时间戳结果目录，历史结果保留。
- `preview.file_index`：从 1 开始。`preview.max_points` 默认为 12000，是显示点数上限。

带宽等原入口继续按文件名解析测量频率。没有频率标注的 `capture_001.csv` 需要有可追溯的输入映射后再适配；平台不根据样点或目录猜测激励频率。元数据与文件名条件冲突时，应先核对数据来源。

特殊入口保持原签名：

| 入口 | 专用输入 |
|---|---|
| AD2208 INL/DNL | `special.continuity_confirmed` 布尔值 |
| AD9245 PICO | `options.interfaces` 与文件逐一对应；桥调用原三参数形式 |
| AD2208/AD677 PICO | 一次一个 MAT，`options.interface` 必填 |
| DA766 十六进制刻度 | `special.tone_frequency_hz`；此入口原签名不支持任意 `options` |
| DAC 隔离度 | `special.pair_manifest`，逐项给出驱动/受扰文件、变量、频率、接口标签和参考面 |

DAC 隔离度每条记录包含 `driven_file`、`victim_file`、`driven_variable`、`victim_variable`、`frequency_hz`、`driven_label`、`victim_label`、`reference_plane`。它明确描述同频参考与受扰配对，不根据文件名猜测驱动关系。

刻度的显式设定值放在 `options.powerSetpoints`。JSON 记录会转成原入口所需的 MATLAB table；这项专用输入不会进入 `configOverride`：

```json
"powerSetpoints": [
  {"FileName":"JG15_001.csv","InputVoltageVpp":0.2},
  {"FileName":"JG15_002.csv","InputVoltageVpp":0.4}
]
```

也支持原入口的 `InputPowerDbm` 列及其他已支持的溯源列。阻抗沿用明确的配置，数值定义由原入口校验。

## 响应与图形

响应中的 `ok` 和 `status` 是任务是否成功的依据。MATLAB 进程正常退出也可能返回 `ok:false`；`error` 保存标识、消息和堆栈。发生错误后已有输出目录列在 `failed_run_folders`。

- `run_folder`：实际新结果目录。
- `final_config`：结果保存的实际配置。
- `tables`：`name`、`columns`、`rows`、`note`、`source_file`。读现有精简汇总定义，缺值保持 `null`。
- `plots`：从保存的 FIG 中读取真实曲线数值或矩阵，包含坐标单位、线性/对数轴、图例标签和来源文件。
- `artifacts`：原结果文件路径及类型。

数组包括单条和空集合也保持 JSON 数组。图形的 `series` 包含 `label/name`、`x`、`y`、`style`；热图包含 `matrix`、`row_labels`、`column_labels`。显示抽取使用分桶最小值/最大值包络，`display_only_decimation` 标记是否抽取；正式分析仍读取完整样点。

输入预览显示解码后的 ADC 码，或未经增益补偿、保留均值的 PICO 实测电压。valid 抽取后的时基尚需由对应入口确定时，预览横轴显示保留样点序号。预览不代替正式频谱计算。

每次运行追加 `evidence/platform_job.json`。DC 输出电压入口保留原有输出布局；桥不补造其原本没有的 XLSX。

## 验证

```matlab
addpath('库目录/tools/platform/tests');
report = run_platform_smoke('指定的全新派生测试目录');
```

该检查在干净路径下读取全部 26 项配置，核对十进制/十六进制预览、非法参数反馈，并对合成 AD2208 ILA 和 DA9726 PICO 噪声执行桥与原入口比较，再以独立 `pwelch` 复算 PSD、1 Hz ASD 和积分噪声。检查属于软件和输入契约验证，不代表板级测试条件或正式指标已经验证。
