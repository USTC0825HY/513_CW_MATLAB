# DAC 公共算法

`runScale`、`runNoise` 和 `runIsolation` 实现DA9726/DA766的刻度、噪声和隔离度计算；PicoScope MAT读取位于同级 `../+io/loadPicoMat.m`。入口配置负责器件固定参数，算法不读取workflow或历史脚本。
