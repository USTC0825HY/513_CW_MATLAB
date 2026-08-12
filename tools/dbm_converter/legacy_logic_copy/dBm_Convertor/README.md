# dBm / Vrms / Vpp 转换器

一个使用 Python 标准库 `tkinter` 编写的图形化换算工具，支持 dBm、Vrms、Vpp 三者相互转换。

## 运行

需要 Python 3.9 或更高版本。在项目目录中执行：

```powershell
python dbm_converter.py
```

在某一输入框中填写数值，然后点击该行的“以此转换”。负载阻抗默认为 50 Ω，也可以自行修改。

## 本地网页版

直接双击 `web/index.html` 即可使用；网页不访问网络，换算完全在浏览器本地完成。

也可以启动本地网页服务并自动打开浏览器：

```powershell
python launch_web.py
```

关闭命令窗口或按 `Ctrl+C` 即可停止本地服务。

## 换算关系

- `P(W) = 10^(dBm / 10) / 1000`
- `Vrms = sqrt(P × R)`
- `Vpp = 2 × sqrt(2) × Vrms`

其中 Vpp 与 Vrms 的关系按正弦波计算，负载按纯电阻处理。

## 测试

```powershell
python -m unittest -v
```
