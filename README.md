# 513 CW MATLAB 分析库

完整分析库位于 [CW_analysis/CW_513_ANALYSIS](CW_analysis/CW_513_ANALYSIS/README.md)。包含2208、9245、9726、766及677的分析入口，以及公共算法、private配置、PICO联合噪声模块和测试。

直接打开对应单项脚本运行，按弹窗选择本次原始CSV或MAT。取消不生成结果；显式文件列表/配对清单可用于复现。各器件说明：

- [2208 使用说明](CW_analysis/CW_513_ANALYSIS/2208_hy/README_先看.md)
- [9245 使用说明](CW_analysis/CW_513_ANALYSIS/9245_hy/README_先看.md)
- [9726 使用说明](CW_analysis/CW_513_ANALYSIS/9726_hy/README_先看.md)
- [766 使用说明](CW_analysis/CW_513_ANALYSIS/766_hy/README_先看.md)

默认路径是维护者的Windows本地路径。在其他电脑运行时，请传入本机的数据目录、文件列表、输出目录和配置。PICO联合噪声需要对应ADC刻度工作簿。仓库不含原始测量数据、实验结果、MATLAB缓存或已删除的历史入口；保留小型测试夹具。

各器件使用说明列出了参数和已知限制。代码执行成功不等于器件指标合格。
