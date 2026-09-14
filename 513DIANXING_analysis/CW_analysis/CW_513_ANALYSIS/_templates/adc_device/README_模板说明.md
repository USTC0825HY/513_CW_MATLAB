# ADC 器件模板

接入前必须确认：正式器件名、采样率、位数、signed/unsigned、CSV 数据列、表头格式、文件命名、分析项目和验收阈值。

器件目录只保留调用公共算法的入口、`private/deviceConfig.m`、`private/bootstrapRuntime.m` 和交接说明。入口不得公开算法参数。配置字段完整且测试、独立包验证通过后，才允许设置 `releaseReady=true`。
