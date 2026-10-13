# 工具目录

- `split_pico_mat_channels.m`：通用 PICO MAT 切分工具。自动识别每个 MAT 内的波形通道数（顶层数值向量变量、排除 Pico 元数据后每变量一路，不限于 A/B/C/D），逐路输出单通道 MAT（波形统一存为变量 `A`，保留 Pico 元数据与时基），附 SHA-256 溯源与 `channel_manifest.csv`。无参数调用弹多选对话框；`(dataFolder)` 自动扫描目录；`(dataFolder, files)` 处理指定文件，均不弹窗。`options.channelMapping` 可自由重命名标签（文件名可带/不带扩展名，未命中的映射行告警），不强制命名规范、不绑定器件目录。结果默认写入数据目录下 `split\run_<时间戳>_pico_split`，源文件只读。
- `buildDeviceRelease.m`：为 `releaseReady=true` 的器件生成已验证独立包；DA包仍保持 `formalEnabled=false`，仅用于迁移和复核。
- `verifyDeviceRelease.m`：在不使用源码父目录的条件下执行静态、依赖和合成数据冒烟检查。
- `data_migration`：历史数据整理脚本，不属于日常分析流程。
- `reporting`：Word 等报告工具；此前只调整了存放位置，报告逻辑未改。

在 MATLAB 中把 `tools` 加入路径后运行：

```matlab
buildDeviceRelease('AD9245')
buildDeviceRelease('DA9726', '0.1.0')
```

## 刻度归档生成

`exportCalibrationArchive.mjs`从公共CSV生成两表单XLSX，`calibrationArchivePrint.py`补充筛选、打印区域和重复表头。只读输入CSV，默认输出到docs/20261012_board_calibration/两套板卡刻度归档_20261004.xlsx；重生成前保留所需旧归档。

依赖：Node.js、`@oai/artifact-tool`和Python标准库。在可解析该Node包的工作目录运行（Codex环境使用load_workspace_dependencies返回的Node和node_modules，临时工作目录建立junction；不在源码库安装依赖）：

```powershell
& '<Node可执行文件>' '<分析库>/tools/exportCalibrationArchive.mjs' --python '<Python可执行文件>' --preview '<任务预览目录>'
```

`--preview`可省略；`--output`可指定独立的归档文件路径。两份20261004报告对应55条数据，工具检查总数和板型行数；报告版本更新时先核对目录表与来源，再调整归档版本和数量。默认标记按接口优先after，否则取唯一记录，数据区数值保持数值类型。验证应读回XLSX并核对报告；成功导出本身不代表来源核对完成。
