# DAC 器件模板

接入前必须确认：正式器件名、更新率、分辨率、输入码型、采集仪器格式、测试项目、标定关系、通道定义和验收阈值。

优先复用 `_shared/+converter/+io`、`+report` 和 `+runtime`。DAC 特有公式放入 `+dac`，不要复制 AD9245 的整套源码。验证完成前保持 `releaseReady=false`。
