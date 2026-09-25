# 513测试器件指标定义与固定参数

本文件说明当前可执行方法。历史结果按其随附参数解释，不能用当前公式重新解释旧字段；黄金基线须独立审核，不能为消除差异而自动更新。

## 2026-09-20 ADC输入、频谱和质量状态

- CSV文本进制与ADC码型分开：`inputRadix=hex/decimal/auto`决定文本解析；adcBits/adcCodeFormat决定位宽和补码解释。auto只接受明确声明等证据；交互运行可确认，显式运行缺证据则报错。实际解析在`evidence/input_decoding.csv`。
- 新结果外层为`结果汇总.xlsx`和PNG；CSV、MAT、FIG、配置、来源哈希、日志和状态保存在`evidence`。原有结果目录不自动迁移。
- SFDR仍按周期Hann窗的单边峰值频点幅度比计算。幅度谱按窗相干增益归一，DC及偶数长度的Nyquist不翻倍，其他正频率翻倍；PSD按`fs*sum(window.^2)`归一并做单边权重。峰值频点法保留非相干采样的栅格敏感性，不能声称已消除栅栏效应。
- 寻找基波前先屏蔽DC；Nyquist保留在杂散搜索内。DC/基波窗口重叠时拒绝计算，避免功率重复扣除。THD现为`10log10(P_harmonic/P_fundamental)`；旧版相反比值的正值不能直接沿用。
- ADC隔离度仍为`20log10(CodePp_driven/CodePp_quiet)`，没有使用各接口V/code刻度补偿。新增RatioBasis明确码比口径；ThresholdMet只表示数值达到比较线，Pass还要求驱动R²（默认0.98）、未削顶、频率符合预期、有效拟合、formalEnabled及isolationReferenceConfirmed。后一个开关只有在参考面及通道增益关系有证据时才可启用，不能为了显示满足而打开。
- INL/DNL在创建运行前核对所有记录的采集通道，不能混合接口。方法为各记录拟合正弦概率加权合并，在共有有效码域计算DNL，再累计并去除最佳拟合直线得到INL。覆盖不足标IncompleteCodeCoverage；理论每码期望命中不足1标InsufficientExpectedCounts；其余标Computed_MethodValidationRequired。缺码与相位/样本不足仍需额外证据区分，FormalConclusion保持暂不能判定。
- 带宽保留每个频点明细，病态拟合或拟合CodePp超过合法码域跨度不参与交点；达到/超过Nyquist的点默认保留并参与交点，仅以NyquistOrAboveFlag标注，只有器件配置`rejectNyquistOrAbove=true`时才剔除（当前无器件启用）。InsufficientCyclesFlag提示少于两个周期；minimumRecordCycles仍由器件配置控制，不静默改变用户参数。少周期的高R²不能证明幅值准确；所有带宽正式结论仍为暂不能判定。

## AD9245 ILA采样率与分析配置

AD9245旧ILA数据曾为25 MHz；当前磁盘ILA配置已为20 MHz。SFDR仍每5点保留1点，因此当前按4 MHz序列加周期Hann窗计算，频谱到2 MHz。旧25 MHz数据显式覆盖后可按5 MHz分析。带宽、隔离度、刻度和INL/DNL不使用这条抽样规则。

当前 `9245_hy/private/ad9245Config.m` 的`ilaCaptureSampleRateHz=20e6`，步长5、分析采样率4 MHz。标签已按配置生成；源/分析采样率和点数单独输出。如要按20 MHz同步全点分析，须显式使用步长1及20 MHz分析采样率。

处理新数据前，按实际采集设置调整分析参数，不能仅凭日期或文件名认定采样率。下表仅适用于AD9245 ILA分析，不是其他器件的通用配置。参数设置方式见 `9245_hy/README_先看.md`。

| 项目 | ILA采样率（按实际数据选择） | 当前其他默认条件 | 输出 |
|---|---:|---|---|
| SFDR | 当前20 MHz每5点保留1点后按4 MHz分析；旧25 MHz需显式覆盖 | 周期Hann窗；NFFT上限128k；DC 16点；基波16点；谐波8点；最高8次 | SFDR、SNR、SINAD、THD、ENOB、Code P-P；当前抽样估算频谱上限2 MHz |
| 带宽 | 旧数据25 MHz；后续20 MHz数据用20 MHz | 拟合 R²≥0.99；最低频连续 3 点为参考；对数频率域插值 | 相对幅度与 −3 dB 带宽 |
| 隔离度 | 旧数据25 MHz；后续20 MHz数据用20 MHz | 10 kHz；驱动通道 X3G；最低隔离 40 dB | 各通道幅度与隔离度 |
| 功率标定 | 当前20 MHz；旧25 MHz数据需覆盖 | 1 kHz；Vpp范围0.1～2.1优先；旧−10至6 dBm范围保留；98%近轨且占比上限1%；正/负轨先达到99%满量程 | CodePp→Vpp刻度、削顶/平台判定、99%临界输入夹逼或范围外外推状态 |
| INL/DNL | 旧数据25 MHz；后续20 MHz数据用20 MHz | 码端余量0；拟合 R²≥0.99 | 码密度 DNL、累计 INL |

当前AD9245配置为14 bit、signed、自动识别数据列（`adcDataColumn=0`）。运行时完整配置会写入 `run_config.mat`。具体公式的可执行定义以 `_shared/+converter/+adc` 为准，文档与实现不一致时必须先停止交付并修正文档或代码。

AD2208与AD9245的INL/DNL自2026-09-09起均设置 `marginCode=0`，不再额外向内裁剪1000码。分析仍取各有效记录拟合正弦范围的交集，并限制在ADC合法码域内；不把输入拉伸到满量程。近轨、毛刺和拟合质量检查保持不变。新结果不能直接沿用旧marginCode=1000的数值基线；旧结果保留，不自动重算。

## AD9245 1 Hz 输入等效噪声（JG18 链路）

此项读取PICO MAT的采样时基，不使用上述ILA的25 MHz或20 MHz。

| 项目 | 固定条件 | 输出与状态 |
|---|---|---|
| 输入等效 ASD @ 1 Hz | PicoScope `A` 通道；`fs=1/Tinterval`；Hann-Welch 目标分辨率 0.2 Hz；AD9245→FPGA `G=128`→DA9726 JG18；`k_DAC=1.014514e-4 V/CodePp` | `S_in=S_Pico[k_ADC/(|G|k_DAC)]^2`；导出 PSD/ASD、源哈希与分段统计。默认不扣 DA/Pico 本底，记录不完整或参考面/需求不足时不得给出正式满足结论。 |

## AD2208 PICO 1 Hz 噪声入口

### 与ILA高频噪声的区别（2026-09-08）

2208 ILA的input_noise配置在2026-09-08改为 `welchSegmentCount=1`、`welchOverlapRatio=0`、`welchNfft=131072`。在100MHz采样、131072有效点下为全长Hann窗一次谱估计，无分段平均，频点间隔762.939453125Hz，时长1.31072ms。单段模式下有效长度不等于NFFT时明确报错，禁止将补零或长度折叠称为整段FFT。保留原10–25MHz频带、刻度、全记录周期图和判据；回归测试比较的是相同输入和参数下的结果，不表示单段结果与旧分段平均结果相同。下述PICO Welch参数没有随之改变。

2026-09-08 入口补充：AD2208 PICO 1 Hz 噪声使用
`2208_hy/adc_pico_noise_1hz_analysis.m` 调用现有联合噪声内核，默认 G=128、
Hann-Welch 0.2 Hz、50%重叠、PICO A、采样率来自 MAT、不扣本底。
AD刻度默认按随代码发布的报告配置匹配器件/接口，显式指定工作簿时使用该工作簿，DA刻度固定为 `1.01451391294771e-4 V/CodePp`，不读取DA9726刻度CSV。
输入等效公式与上节相同；该入口未改变公式或正式状态规则。

## ADC128 带宽

入口位于 `128_hy`，12 bit unsigned，默认CSV第5列为ADC码、第4列为valid。ILA时钟50 MHz，sampleRate默认NaN，从均匀valid选通间隔推导有效采样率；显式有限sampleRate可覆盖。读取原始码后减2048，不改变CodePp。FFT估频并优化，再联合拟合正弦/余弦/直流项，`CodePp=2*hypot(a,b)`。最低频3个有效点幅值中位数作参考；响应为20log10幅值比，−3 dB在log10频率轴插值。R²门槛0.99，频率匹配检查启用。当前下轨余量−1意味着触及原始0码不会被削顶筛选排除，上轨余量1仍生效；该放宽需连同原波形审查，不能表示无削顶风险。达到或超过有效Nyquist的点默认保留并参与带宽，仅以NyquistOrAboveFlag标注（内核仅在器件配置rejectNyquistOrAbove=true时剔除，ADC128未启用）。源阻抗去嵌规则默认未启用，输出为实测带宽；无刻度时为CodePp而非Vpp，无正式验收限值，结论为“暂不能判定”。

## AD677

| 项目 | 采集/固定条件 | 输出与判定 |
|---|---|---|
| ILA噪声 | 100 MHz全记录点；131072点Hann；1 Hz～10 kHz；valid只统计更新率 | 固定677_1/677_2斜率换算PSD/ASD；无正式限值，暂不能判定 |
| PICO 1 Hz噪声 | MAT时基；G=128；DA9726 JG18；0.2 Hz；50%重叠；不扣本底 | AD677输入等效PSD/ASD；记录至少约5秒；无正式限值，暂不能判定 |
| 输入频率响应 | 100 MHz ILA时钟；16 bit signed；ADC第4列、valid第5列；从选通间隔推导有效采样率并去掉保持行；文件频率拟合；R²≥0.90；周期门槛0、频差不强制排除；最低3个有效点归一化 | 保留CodePp、相对dB、频差及质量标记；Nyquist/病态拟合不参与交点，少于2周期提示；无交点不外推；正式暂不能判定 |
| 输入功率刻度 | 1 kHz；0.25–2.5 Vpp；`Vpp=a*CodePp+b`；near-rail/削顶点保留但排除；由未削顶点外推正负轨99%临界值 | Vpp、CodePp、斜率、截距、R²、残差、有效范围、排除原因、反向公式及临界值外推状态 |

AD677 manifest 记录信号源为 SDG6032X-E 且 `LOAD=HZ`。Vpp 是信号源高阻模式显示设置值，板连接器/ADC引脚参考面、实际终端和指标限值未确认，因此 `formalEnabled=false`，正式状态为“暂不能判定”。

ILA噪声去均值后只乘斜率：677_1为1.536050e-4 V/code，677_2为
1.695154e-4 V/code，不使用截距。100 MHz是ILA记录时钟，有效转换更新率由
`adc_data_vld` 统计，两者不能混写。PICO换算固定使用DA9726 JG18斜率
1.01451391294771e-4 V/code。现有 `ad677_noise_G128_CH1.mat` 约10 ms，
不足以按0.2 Hz分辨率分析1 Hz ASD，需补采至少约5秒的数据。

临界输入估计不改变刻度点筛选：仍用98%近轨门限和1%样本占比识别削顶点；99%仅作为正、负拟合轨的目标码值。存在首个削顶点且估计落在“最高未削顶—首个削顶”区间时标记为 `bracketed_estimate`，否则标记为 `unbracketed_extrapolation` 并要求补扫验证。

## DA9726 / DA766

| 项目 | DA9726 | DA766 | 说明 |
|---|---|---|---|
| 刻度 | DAC1_JG18按1001000 Hz固定频率正弦拟合；文件名CODE/COADE按16位十六进制无符号码读取，横轴为raw unsigned code；Vpp-Code一阶拟合 | 采集证据固定音调后正弦拟合；本批 2026-08-26 数据为1525 Hz，16位补码换算后CodePp=2×abs(signed code)，且纳入`0x7FFF` | DA9726当前9个MAT约39.062499 MSPS，历史成功结果斜率约1.0145139e-4 V/code；DA766标准A批次与历史CH2/B批次须分开拟合 |
| 噪声 | Welch 目标分辨率 0.2 Hz；最少 4 段；ASD与1～100 kHz积分PSD | 目标分辨率 0.2 Hz；需重新审计记录长度和覆盖 | DA9726当前同时输出ASD和积分RMS；图仍以ASD为主 |
| 隔离度 | 驱动端/受扰端/通道/频率/参考面由配对清单明确给出；结果以驱动×受扰 dB 矩阵和热力图展示 | 同左 | `dac_isolation_summary.csv` 保留逐对 `isolation_db`，另输出 `dac_isolation_matrix_db.csv`；信息不全时为“暂不能判定”，40 dB参考阈值不用于热力图坐标范围 |

本库暂无DA相噪、独立DC输出电压、线性度及DA766更新率/分辨率的正式入口；正式结论开关由器件配置中的 `formalEnabled` 控制。

## 2026-09-20 噪声输入与覆盖规则

DA9726/DA766噪声默认电压增益100，刻度/隔离默认1；电压在读取时仅除一次增益。PSD由MAT实际时基的一侧pwelch得到，积分在PSD域梯形积分后开方，完整频带时线性插入两端频点。积分完整覆盖要求上下限均在实际频谱内且至少两个频带内频点；单点不报告零RMS。ASD覆盖还要求目标分辨率、最少4段和频点误差门槛。formalEnabled=false继续限制正式结论。

MAT显式通道不得自动替换，未指定时只接受唯一A/B/C/D；NaN/Inf拒绝处理而不是删点压缩时基。合法压缩MAT交由MATLAB load验证，不能用文件体积小于变量解压大小判为截断。PICO联合噪声增加实际通道、实际频点误差与覆盖字段；全部失败写STATUS_FAILED，部分失败写STATUS_PARTIAL，不再统一成功。

DAC正弦拟合增加0<f<fs/2及至少4样点校验，采样以上的名义频率不能直接当作可观测频率拟合。刻度线性拟合至少两个不同有效码幅；DA9726横轴仍保持raw_unsigned_code，DA766保持2×abs(signed code)，不混改定义。summary增加code_axis_definition与formal_conclusion，兼容旧code_vpp字段名称时必须连同定义读取。
