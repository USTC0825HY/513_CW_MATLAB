# 工具目录

- `buildDeviceRelease.m`：为 `releaseReady=true` 的器件生成已验证独立包；DA包仍保持 `formalEnabled=false`，仅用于迁移和复核。
- `verifyDeviceRelease.m`：在不使用源码父目录的条件下执行静态、依赖和合成数据冒烟检查。
- `data_migration`：历史数据整理脚本，不属于日常分析流程。
- `reporting`：Word 等业务报告工具，本轮只归档位置，不改变报告逻辑。

在 MATLAB 中把 `tools` 加入路径后运行：

```matlab
buildDeviceRelease('AD9245')
buildDeviceRelease('DA9726', '0.1.0')
```
