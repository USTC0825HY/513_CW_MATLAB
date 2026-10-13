# 规则、技能与刻度归档更新（2026-10-13）

## 交付

- [当前结构及26入口](STRUCTURE.md)、[全部源码分类及哈希](SOURCE_STRUCTURE.csv)。正式入口、private、公共内核、测试、切分/批处理/FFT、Phase_delay及归档工具分别分类。
- [刻度归档XLSX](../20261012_board_calibration/两套板卡刻度归档_20261004.xlsx)：仅鉴定件、电性加强件两表单，27+28条，含全部前后版本。默认记录在同接口内置前；唯一改焊前记录仍保留“改焊前”状态。
- 项目AGENTS、PROJECT_MEMORY、RESOURCE_INDEX、SCRIPT_AUDIT_LEDGER及README/CALIBRATION已更新；没有另建重复agent/memory/skill文件。
- 本地laser-electrical-data-analysis主文件及script-routing、workspace-map、calibration-workflow三引用已同步Codex/ZCode。技能系数仍引用项目数据，不复制维护。同步哈希见[skill_sync.json](skill_sync.json)。

## 检查结果

55条记录与CSV及两份Word刻度原表斜率、截距逐行一致，原Word SHA-256保持一致。XLSX数值类型、版本默认值、日期、缺测空白、来源位置、冻结、筛选、打印范围及重复表头已检查。完整记录见[archive_checks.json](archive_checks.json)。

artifact-tool生成并检查工作表，LibreOffice只读转换PDF进行打印检查，共4页A3横向，每表单2页；续页重复表头。检查了两表单的系数显示、日期、配色与说明，未进行Excel桌面人工操作。

169份现有.m和公共刻度CSV共170文件哈希不变。此轮没有运行新的MATLAB数值回归，也不新增板级指标结论。

技能quick_validate在Codex和ZCode两侧通过。系统Python3.6含PyYAML，调用时仅为当前进程的Path.read_text指定UTF-8，以适配Windows默认GBK；验证器文件未修改。打包Python未安装PyYAML，未改动运行时依赖。

## 维护方式

CSV供代码读取；XLSX从CSV生成归档，修改XLSX不改变分析配置。生成说明见[tools/README.md](../../tools/README.md)。输入和系数不变时可指定--output独立重生成；报告版本变化需重新核验。

项目文件推送到既有codex/ad677-noise-sync分支；技能在用户技能目录同步，不放入MATLAB仓库。原始数据、结果、ZIP及其他工程保留。

备份、预览及执行记录：F:/01_Laser/.codex_work/20261013-governance-calibration-archive。历史项目记忆中的版本记录保留，当前摘要优先用于新任务。
