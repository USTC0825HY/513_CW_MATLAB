# 两种板型刻度配置实施记录（2026-10-12）

已将鉴定件与电性加强件的刻度分开管理，覆盖AD2208、AD9245、AD677、DA9726、DA766。以两份20261004报告刻度表为依据，共55条（鉴定件27条、加强件28条），逐条核对斜率、截距、改焊版本、表格位置和报告SHA-256。详细对照见[刻度逐行对照.csv](刻度逐行对照.csv)。未知R²、日期等保持空白。

## 使用方式

长期维护位置为`_shared/+converter/+calibration/report_calibrations_20261004.csv`，完整说明见[CALIBRATION.md](../../CALIBRATION.md)。该文件是配置源码，已添加局部Git忽略例外，后续版本管理可识别它。

在2208_hy目录运行：

```matlab
% 弹窗选CSV、接口（按需）、板型及进制（按需）；取消即结束
adc_ila_noise_analysis

% 显式文件调用：dataFolder、selectedFiles、outputFolder由用户设置
options = struct('boardType','jianding', ...
    'calibrationState','current','inputRadix','decimal');
result = adc_ila_noise_analysis(dataFolder,selectedFiles,outputFolder,options);

% PICO：明确接口；同板型DA9726 JG18自动配套
options = struct('boardType','jiaqiang', ...
    'calibrationState','current','interface','ADC6_JG24');
result = adc_pico_noise_1hz_analysis(dataFolder,selectedFiles,outputFolder,options);
```

`inputRadix`按实际CSV设置为decimal或hex；明确基数声明的文件也可保留auto。`current`优先改焊后，否则采用唯一记录并保留其原状态。`before`、`after`仅选对应版本，版本缺失会列出可用状态。显式文件调用使用内置刻度时须填boardType，每次调用独立选择。

| 入口目录 | 接入的噪声入口 | 参数签名 |
|---|---|---|
|2208_hy|adc_ila_noise_analysis|dataFolder, selectedFiles, outputFolder, runOptions|
|2208_hy|adc_pico_noise_1hz_analysis|dataFolder, selectedFiles, outputFolder, runOptions|
|9245_hy|adc_input_noise_analysis|dataFolder, outputFolder, runOptions（文件放runOptions中）|
|677_hy|adc_ila_noise_analysis|dataFolder, selectedFiles, outputFolder, runOptions|
|677_hy|adc_pico_noise_1hz_analysis|dataFolder, selectedFiles, outputFolder, runOptions|

DAC电压噪声仍使用实测电压和增益。刻度扫描继续拟合所选原始数据。SFDR、相对带宽、码比隔离度和INL/DNL保持原有计算，不引入刻度选择。

## 生效及来源记录

运行显示板型、接口、版本、斜率，PICO同时显示DAC系数。最终配置的calibrationSelection保存实际记录；精简XLSX上方显示板型和版本。完整来源位于evidence的report_calibration_rows.csv（ILA）、selected_adc_calibration.csv和selected_dac_calibration.csv（PICO）、MAT及script_source_manifest.csv。

允许显式结构体、工作簿及DAC刻度CSV复跑。自定义来源标为user；相互竞争的ADC来源、DAC来源和混合内置/自定义链路给出明确冲突提示。完整已解析配置复跑检查系数和来源的一致性。

## 验证

- 两份当前Word文件55条刻度与目录表逐行一致；报告SHA-256保持不变，见report_sources.json。
- MATLAB R2025b使用干净路径执行单元、集成及可移植性检查，最后两批30/30、13/13通过；分批合并228个不同测试的最近一次结果全部通过。分批及按测试名汇总见test_runs.json、regression_latest.csv。
- 新建合成数据覆盖2208 JG24鉴定件/加强件改焊前/后，9245四路、677两路及同板DA9726 JG18；检查ASD/RMS斜率比、PSD斜率比平方、PICO ADC/DAC比及增益128。
- 覆盖取消选择、缺板型、版本缺失、自定义冲突、显式历史系数和工作簿复跑。文件选择和板型取消使用自动化UI替身。
- 保留AD677历史系数测试数值，通过显式自定义刻度复跑；没有覆盖历史黄金期望值。
- 25份ADC/DAC计算内核源码与任务开始时一致，PICO localWelch/localSegmentAsdAtBin函数体一致；见source_change_audit.json。
- CSV新增单行/55行含换行来源说明往返测试；最终3个2208 PICO输出包检查CSV行数、XLSX条件说明和目录表哈希，见bundle_checks.json。XLSX经MATLAB读取及ZIP/XML解析核验。
- 抽查合成PICO677 ASD图片，白底黑字浅灰网格、频率轴及1 Hz标记可见。

首轮回归226项中215项通过、11项失败。后续修复单记录结构体转表、来源文件记录，以及测试驱动路径；新增比例检查改用相对谱峰误差衡量FFT近零频点。来源说明含换行的CSV统一加文本引号。初始失败日志保留，汇总取每项最近一次运行结果。

checkcode记录在final_checkcode.json和export_checkcode.json；保留日期API现代化和既有抑制标记提示，不为消除提示改写计算。

## 范围及后续使用

本轮为软件配置和合成/夹具数据验证，历史大型实测批次未重算；板级测量条件及正式合格结论沿各次测量记录评价。R2018运行、发布ZIP重制和逐入口人工GUI操作未执行。Excel通过程序读取，未进行Excel桌面人工查看。

切换板型或刻度版本后，新的噪声数值会相应变化。历史报告、历史结果和原始数据保持原样；没有提交或推送Git。任务开始前已有工作区修改保留。本次更新五个器件README、公共刻度/配置说明及项目记忆和台账。

完整执行日志、测试MAT及派生结果：[工作目录](F:/01_Laser/.codex_work/20261012-board-calibration)。
