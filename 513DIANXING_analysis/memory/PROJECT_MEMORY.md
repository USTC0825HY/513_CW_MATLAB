# CW_513_ANALYSIS 项目记忆

2026-09-28（鉴定件 JG17 PICO 补入）：JG17 改焊后 PICO 复测（`02_1Hz_PICO\ADC2_JG17\raw\JG17_NOISE_250KSPS_CH1_MULT128-retest.mat`，0922 采集，与加强件不同批）入报告——已有 run_20260922_212400 复用（k=4.43806e-5 恰与鉴定件报告刻度一致，无需重算），**1 Hz ASD=4.092 µV/√Hz**、分段 2.770~6.938，满足。PICO 表 4 行（JG17 后蓝 / JG24 后蓝 / JG24 前红灰）、图11 JG17+图12 JG24、结果说明合并两路、溯源行补 run。**重大坑（已修）**：`xml.rindex('<w:p',…)` 会误匹配段落内部 `<w:pPr` 前缀——图段插入点必须用段落级正则数组定位（找题注段索引后向前找含 <w:drawing> 的完整段），否则图被插进另一段落中间形成非法嵌套、LibreOffice 静默丢弃该图（XML 层题注计数正常但渲染缺图，postcheck 难以发现——渲染层图号抽查必要）。另：「DA9726/PICO」连写在窄列易被断词，改「DA9726 与 PICO」。交付 md5 ec84a82f。

2026-09-28（鉴定件 PICO 1Hz 更新）：JG24 改焊后 PICO 复测（`02_1Hz_PICO\ADC6_JG24\retest\JG24_250K_CH1\JG24_250K_CH1_1.mat`，与加强件不同批 sha256 不同）分析完成——**k_adc 经 calibrationWorkbook 选项注入**（新建最小 xlsx `F:/01_Laser/.codex_work/20260929-jd-pico/jd_ad2208_cal_20260924.xlsx`，Sheet=刻度参数，含鉴定件 0924 报告 5 行刻度，JG24=3.788345e-5；loadAdcCalibration 接受函数路径或此格式 xlsx，注意根目录 20260822 旧 xlsx 含重复行会触发唯一性校验失败不可直接用），run=同目录 results\run_20260928_134711。**1 Hz ASD=3.908 µV/√Hz（改焊前 5.249）**，分段 0.499~4.742，满足。报告更新：误差路方法段补 k 说明；小节重排为 spec 序（方法→要求→ILA表→PICO表→结果说明：标签→两段说明→图）；PICO 对比表（改焊后蓝 3.908/改焊前红灰 5.249/— ）；旧 PICO 图换新 run 图（图11）；溯源行补两 run 路径。排版坑：**双行对防拆须给配对首行（改焊后行）全部段落加 <w:keepNext/>**（cantSplit 只防单行内拆）；整表被推页后注意「结果说明：」标签段别孤悬页底（同样 keepNext 或确认位置）。交付 md5 6d2bbd15。

2026-09-28（鉴定件 ILA 噪声更新）：鉴定件 20260924 报告 AD2208「输入等效噪声」小节按 `I:\CW_Data\513_CW_DATA_jianding\AD2208\06_Noise\01_HighFrequency_ILA\ila_noise_reset\20260924_103139`（5 通道 CSV）复测更新——标题去"-还没更新"、删 ILA 待补充标注、旧混合表换加强件同构对比表（JG15/17/19/22 改焊后蓝行 22.22/37.71/21.48/21.48 中位 + 改焊前红灰行 26.69/45.43/21.32/26.13（旧表无 95%/频率列，填"—"）；JG24 单蓝行 33.02 用鉴定件本板刻度 k=3.788345e-5 经 runOptions.reportCalibration 覆盖注入，不动共享库）、旧图 12-15 换新 run 图+新增 JG24 ILA 图（题注全文重编 1~85）、结果说明注明误差路仍为改焊前口径 5.249 μV/√Hz 待复测。分析 run=同目录 `run_20260928_133201_input_noise`（inputRadix='decimal' 显式）。**重要事实（已告知用户）：该批 5 个 CSV 与加强件 `ila_nosie\01_gaihanhou_0924` 的 5 个 CSV 逐文件 md5 相同**——同一批采集放两板目录，两报告 ILA 数值将一致（JG24 因刻度差 0.36%）。脚本坑：①段落替换必须严格按文档位置降序（先改前面段落会使后面锚点陈旧偏移失效→删错区域）；②cell 模板 rPr 需闭合 </w:rPr>；③converter 包在入口自举前需自行 addpath _shared。交付 md5 a6a8d4d0。

2026-09-28（鉴定件 GTH&RF 补全）：鉴定件 20260924 报告用 SNH 0925 源稿（`I:\CW_Data\513_CW_DATA_jianding\鉴定件-GTH&RF输出测试结果 .docx`，注意文件名含空格）补全 GTH&RF——旧 SZSD-GTH(JG10-无功放) 与 SZSD-RF射频IO-复测 两章替换为新「SZSD-GTH&RF输出」章（4 三级小节+4 表+16 图：源稿 14 张 + 保留旧章独有的 1MHz/1GHz 频谱 2 张），鉴定件数值与加强件独立（功率 -0.34/-1.76/-6.17、RF 10.41/10.33/10.73/5.26、谐波全不满足、秒稳 100M 仅 SMB100B 满足）。**顺带修正基线章序缺陷**：上轮重排把 ADG526 遥测章错排在 DA766 之后（KEYS 顺序 bug，当时视觉验收提示被我误判），本轮移至 AD128 之后附录之前。题注重编号 1~84（引擎升级：占位"图N"与数字题注统一按文档序重编）。溯源表 GTH/RF 行已更新（RF 8 频谱+秒稳截图仅存源稿 docx 未归档 I 盘，已注明）。**剩余数据缺口（下轮计划）**：①AD2208 ILA/PICO 噪声复测更新（无新数据）；②频率计数器指标限值（无数据）；③遥测 0xB0/0xC0（I 盘 addr_B0.csv 属光电接口板数据，非遥测，已排除）；④AD9245 隔离度、传输延迟原始数据目录；⑤RF/秒稳 10 张截图归档。交付 md5 17bc8025，工作区 `F:/01_Laser/.codex_work/20260929-jd-gthrf-fill`。

2026-09-28（两报告重排交付）：加强件 0927 与鉴定件 20260924 两报告已按新格式规范重排并覆写权威路径（工作区 `F:/01_Laser/.codex_work/20260929-report-reorder`，重排引擎 restructure_lib.py）。加强件：章序 AD2208→DA9726→GTH&RF→TLV2548→AD9245→DA766→AD677→ADC128；20 个图块移至小节末；题注全转纯文字 1~84 连续（SEQ 域全部移除）；GTH 功率/秒稳表 R0 gridSpan 修正（v2 split 遗留：span2 配 1 数据列导致 LibreOffice 幻影列）；补溯源附录 55 行。鉴定件：12 章按板组重排（GTH→RF射频IO 相邻、传输延迟在 SZSD 组末、遥测链路在 YCQD 末）；题注 1~76；5 处灰色【待补充】标注（GTH 功率/秒稳小节、RF射频IO 指标要求与判定、计数器限值、遥测链路指标与 0xB0/0xC0、AD2208 噪声更新）；溯源附录 33 行（部分待补充）。均过 visual-judge 终验。引擎坑（已入 lib）：① Word 重存会重编号 styleId，标题识别必须按 styles.xml 名称映射（一级=173 等）；② move 引擎 rest 范围必须 range(s+1,e)，否则小节标题被复制成 ghost；③ body 重建须保留元素间 gap 与 sectPr 尾段；④ 题注 SEQ 域重排后统一转纯文字；⑤ 字符串含 \01 会被 Python 转义为控制字符破坏 XML。鉴定件遗留标注清单（后续完善计划）：GTH 功率/秒稳、RF射频IO 判定、计数器限值、遥测 0xB0/0xC0、AD2208 噪声更新、溯源表待补充行。

2026-09-28（报告格式固化）：laser-test-report-writing 固化完整格式（权威 `references/report-format-spec.md`）。用户定稿口径：章节顺序=SZSD(AD2208→DA9726→GTH&RF输出→SZSD_yaoce/TLV2548→SZSD_频率计数器)+YCQD(AD9245→DA766→AD677→ADC128→YCQD_yaoce/ADG526+AD677)，与数据 taxonomy 对齐；小节内顺序=方法→指标要求→表→**结果说明→图（图在小节末尾）**；溯源=文末「附录：数据溯源表」（7列，实际物理路径，正文零改动），make_traceability_rows.py 自动提行（旧根+新根双模式，已 6 路径自测；坑：run 时间戳 8+6 位、JGxx_ 下划线吞词边界需 (?![0-9A-Za-z])）。method-templates.md 收全部小节方法/要求逐字模板+槽位。SKILL.md 旧"路径不入报告"规则改为"路径仅限溯源附录"。14 条目双侧安装，证据 `C:/Users/86183/.codex/hardware-assets/maintenance/20260928-report-format-skill`。**报告侧待办（0927 未动）**：章节重排至新板组顺序+图号重排、图位调至结果说明后、补溯源附录。

2026-09-28（数据管线技能阶段1）：新技能 `laser-cw-data-pipeline` 落地数据整理规范 v1.0——`I:\CW_Data\鉴定件\|加强件\ → SZSD|YCQD → 器件 → NN_指标(闭集) → 接口(闭集) → YYYYMMDD_HHMM 会话{raw,results,_session.md}`；骨架已落 I 盘（74 目录+26 INDEX，audit_tree 0/0），旧根不动；AD2208 噪声拆 06_NoiseIla/07_NoisePico 两指标夹、时钟源归 10_ClockSource（待确认）、改焊状态由日期对照 2026-09-19 判定。脚本：scaffold_tree/audit_tree/make_legacy_map（闭集在 taxonomy.py）。存量映射草稿（须人工确认）在 `C:/Users/86183/.codex/hardware-assets/maintenance/20260928-data-pipeline-skill/`：加强件 232 叶子目录（全链138/未映射32）、鉴定件 703（314/37）。阶段2-4（处理/文本/校验）占位待规划。坑：Windows 大小写不敏感，同父目录小写重名目录不可构造。

2026-09-28（TLV2548+ILA 口径）：0927 报告（以用户删除 JG17/JG24 行/图后的版本 02bfbb23 为基）追加第 8 章 SZSD-TLV2548「8通道遥测码值」——三段式+8 行码值表（SIG_IN1~8，0x360/864/0.8440V…0x04F/79/0.0772V，换算按 4V/4096 仅供参考）+图95 8通道遥测输入映射（原理图截图，取自 I 盘鉴定件 SZSD_TLV2548.docx）；限值未确认→正式状态「暂不能判定」；数据链=I 盘 20260815 ILA CSV≡同事 20260901 原稿表值（微信加强件 rar 0918 无解压工具未解，数据源已注明）。同步清理 ILA 结果说明对已删行的引用（改"JG17/JG24未复测，不列结果"）。Skill 固化：rework-comparison-style.md 新增「未复测接口是否展示按各表既定口径，AD2208 ILA 表只列复测接口（JG15/JG19/JG22），不得恢复已删行」，SKILL.md 同步；2 文件×2 侧安装（backup 在任务区）。遗留如实报告：ILA 表底边框中部缺失为用户删行后 Word 保存的既有状态（像素级与基线一致，非本轮引入），建议 Word 里确认。TLV2548 无 datasheet 于 F 盘。工作区 `F:/01_Laser/.codex_work/20260928-tlv2548-ila-skill`，交付 md5 a4690200。

2026-09-28（对应性审计与修复）：对 0927 报告做了全文「数据-结果-图片」对应性审计并修复（工作区 `F:/01_Laser/.codex_work/20260928-data-figure-consistency`，交付 md5 b569ac75）。审计结论：85 图-85 题注一一配对、25 处区间 24 处与表极值一致、6 组 I 盘源头抽核全过；唯一实质错图=图69~73（ADC128 带宽）错用 DA766 改焊前噪声图（image59-63 双引用，ADC128 图从未嵌入过——0726 早期版本遗留）。修复：①图69-73 换 `ADC128\01_ad128_input_freq\results\summary_bandwidth_20260919` 5 张带宽图（1990×1199，新 rId96-100）；②图63-65 换 DA766 改焊后噪声 run ASD 图（新 rId101-103，与 T24 表主行口径一致；图66/67 无复测维持改焊前图）；③AD677 带宽文字 12.20/19.51→12.13/19.44（对齐表值）；④DA766 满量程 10.4→10.24V；⑤GTH 秒稳说明区分参考源（SDG6032 组 100MHz 1.17E-12 不满足）；⑥AD9245 刻度表 4 处 U+2073 杂散字符、AD2208「0 V。。」双句号、T02 刻度表 R1-R4 k/b 拆双段落。已知残留（用户知悉）：图79/80 内嵌带宽标注（12.1956/19.4435 kHz）为其自身 run 口径，与表 T27（12.1321/19.4393）固有差异约 0.5%，文字已对齐表格，图未重生成；JG17 双口径维持；图号缺号/乱序不重排。坑：字符串替换对跨 run 文本无效须段落级重建；新文本含 < 须写 &lt;；cell 内偏移误当表级偏移会破坏相邻 XML（改用唯一段落串替换）。

2026-09-28（接口列合并）：按用户要求以带宽表为蓝本，把 0927 报告 T03 ILA×3 对、T04 PICO×1 对（重复名）、T07 INL×5 对（后缀）的接口列改为 vMerge 纵向合并（其余 31 表字节不变，T00/T01 单行、T02/T21/T22/T23 已合并不动）；已覆写权威 docx，visual-judge 3/3。技能同步：rework-comparison-style.md 固化合并蓝图（禁止重复名/（改焊前）后缀）、审计新增 REWORK.MERGE（必须用 lxml tr_lst 层——python-docx 对 vMerge 延续格返回原点格对象，文本级检测失效，已实测 same _tc）、format_rework_table 自动合并相邻对、verify 的 stale-merge 断言改为「vMerge 必须在改焊表内」。14 条目双侧安装，证据 `C:/Users/86183/.codex/hardware-assets/maintenance/20260928-report-skill-merge-blueprint/`。工作区 `F:/01_Laser/.codex_work/20260928-interface-merge`。

2026-09-27（GTH&RF v2 重构）：按用户要求把 GTH&RF 章的功率与秒稳拆为三级小节——7.1 GTH输出 / 7.2 四路RF输出 各下分 输出功率、秒稳（样式 a1 三级标题，正文首次启用；多级编号第三层 7.1.1 等自动显示）。每小节独立三段式+独立表格：功率表只含功率（RF 表含谐波抑制）、秒稳表只含秒稳；频谱图归功率小节、秒稳曲线归秒稳小节，图号 81-94 按新文档顺序重排（media 映射同步重排）。两个修复教训：① LibreOffice 对共享同一 abstractNum 的多个 numId 不重启计数，列表重启必须加 `<w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/>`（v1 曾全章连号 4)…15)）；② figs() 分组调用时 rId 偏移要作参数传入，否则各组都从 rId82 起编导致 8 张图错映射（v1 同病，验收漏检，本轮已用像素尺寸 1707×976=秒稳/1040×784=频谱 程序验证 14/14）。交付前并发校验的参照基准必须是"本人上一次交付版"而非更早基线；本次覆写前文件经字节数精确匹配（7751112 B）确认为 v1 原样、无用户改动被覆盖。终验 visual-judge 10/10（逐图核对截图内嵌测量值与表格一致）。工作区 `F:/01_Laser/.codex_work/20260928-gth-rf-report`（v3 交付 md5 b8f9ee3669fb5a13b0e86fc6714d7732）。

2026-09-27（GTH&RF 并档）：电性加强件 0927 报告末尾追加 `SZSD-GTH&RF输出` 章（工作区 `F:/01_Laser/.codex_work/20260928-gth-rf-report`，append-only 已覆写权威 docx，56→64 页）。内容：GTH JG10（4.5/100/500/1300MHz 功率+秒稳，SMB100B/SDG6032 两组参考，500M/1.3G 秒稳超 53100A 量程待测试）与四路RF（JG1/JG4/JG5 100MHz、JG8 20MHz 功率/秒稳/谐波抑制）；均 20260922 改焊后采集、无改焊前对照（章内备注注明）。源稿=微信《加强件-GTH&RF输出测试结果.docx》（SNH/WPS）；频谱 PNG 与 I 盘 `GTH\20260922-jiaqiang-GTH`、`RF_REF\20260922-jiaqiang-RF_REF` 字节一致；数值以源表为准（.tim 未重算）。编辑要点：新章用样式 a/a0 + 新 numbering numId 39/40（克隆 abstract 7 实现每小节 1)2)3) 重启）；图81~94 纯文字题注（尾部先例，不用 SEQ）；两级表头 vMerge+gridSpan 自建；源图保持原生 extent（秒稳 14.63×8.37cm、频谱 13.93×10.50cm）。坑：`<w:drawing>` 闭标签是 `</w:drawing>` 非 wp:；python 读写 XML 须 newline='' 否则 CRLF→LF 破坏前缀字节一致性校验。

2026-09-27（技能）：改焊前后状态列样式已固化进报告书写技能。`laser-test-report-writing` 权威范本升级为 电性加强件 SZSD_YCQD_20260927.docx（0920 为改焊前基线参考），新增 `references/rework-comparison-style.md`（状态列、改焊后蓝 B8CCE4 在前/改焊前红 E5B8B7+灰 595959 在后、接口列白底、JG15 标准与存量变体、超差加粗、公式格双段落、图 13.5×9cm+MATLAB print 导出、同基准对比/包络取表内极值/方法段参数溯源等）；审计脚本新增 REWORK.ORDER/REWORK.GRAY 咨询级检查（未复测单行与 DA766 变体豁免），模板含改焊对比示例表，verify 工作流 6 项断言；`laser-electrical-test-report-standard` 加交叉引用。11 文件×2 侧（.codex 权威/.zcode 副本）已安装并冒烟；证据：`C:/Users/86183/.codex/hardware-assets/maintenance/20260927-report-skill-rework-style/`（README/deployment.json/SHA-256/备份指针），staging 与 qa 在 `F:/01_Laser/.codex_work/20260927-report-skill-rework-style/`。对权威 0927 跑新审计零误报。

2026-09-27：电性加强件 0927 报告全表状态列改造完成（工作区 `F:/01_Laser/.codex_work/20260927-report-status-cols`，已覆写权威 0927 docx）。① 排版规范固化：结果表加"状态"列（焊接情况），改焊后行在前（数据格浅蓝 B8CCE4，2208 含状态格；DA766 状态格不染）、改焊前行在后（浅红 E5B8B7+灰字 595959，接口列白底，改焊前行接口名留空由状态列承载）；AD2208 T0饱和/T1刻度/T2带宽/T3ILA/T4PICO/T7INL 与 DA766 T21输出电压/T22刻度/T23噪声 均已办理。② ILA 噪声表按用户指示只更新 JG15/JG19/JG22（复测值），JG17/JG24 保持改焊前口径单行。③ JG17 PICO 复测：`02_gaihanhou_0922/JG17_250K_CH1_Reset/results/run_20260924_112927`（1 Hz ASD 4.140 µV/√Hz）；注意其 k_adc=4.43806e-5 来自 0903 旧文档组，而报告 T01 刻度表 JG17 改焊前 k=4.4031936e-5（0915 拟合），两处差 0.8% 待统一。④ JG24 PICO 已核实用改焊后刻度 k=3.802132e-5 ✓。⑤ DA766 三路噪声折算不经过码值刻度（PicoScope 电压÷硬件增益 100），新旧刻度不影响 ASD 数值；其 run 内嵌 reportCalibration 元数据仍为 0903 旧值（3.04e-4），仅元数据陈旧。⑥ DA766 输出电压改焊后行来自 `OUTPUT_AMP/gaihanhou_20260924/results/run_20260925_113851_output_voltage`（X11-5/6：-0.157～+10.079 V，X11-7：-0.315～+9.921 V）。⑦ 勘误：DA766 噪声方法段"其余五路 2.48MS/s、100s"系从 DA9726 段误拷，实为 1.978 MS/s、20 s（run_20260918_235012 证实，改焊前后采集条件一致）。⑧ 编辑坑：公式格两行显示用双段落结构（k 段+b 段），不要单段内 <w:br/>；JG24 蓝行曾被拆坏（⁵ 落在第二段段首）。报告仍保留的用户标记：SFDR 黄高亮（ADC6 频点待补）、隔离度-需要重测、"调节精度1mV"品红、"4.3输出噪声"标题黄高亮。

2026-09-26：AD2208 改焊后噪声复测分析落盘 I 盘并写入电性加强件报告（工作区 `F:/01_Laser/.codex_work/20260926-cw-report-continue`）。① ILA 高频噪声：`I:/CW_Data/513_CW_jiaqiang/AD2208/05_noise/ila_nosie/01_gaihanhou_0924/results/run_20260926_212046_input_noise`，5 通道 10~25 MHz ASD 全部满足（中位 21.48~37.71、最大 81.7~143.8 nV/√Hz）；中断会话仅导出 3 通道 PNG，缺的 ADC2_JG17/ADC6_JG24 由 .fig 以 15×10 in @150 dpi 重导出（exportgraphics 直接导出会得 1545×1127，与报告 1.5 版式不符，须 print+PaperPosition）。② PICO 1 Hz：`.../05_noise/PICO_1hz/02_gaihanhou_0922/results/run_20260926_220512_ad2208_pico_noise_1hz`，JG24 实测 1 Hz ASD 3.694 µV/√Hz、分段 1.682~5.563 µV/√Hz，与报告既有数值逐位一致（证实报告值即该复测数据、非旧值折算）；ADC2/JG17 无改焊后 PICO 采集，报告中已标（改焊前）。③ 报告新增排版约定：改焊后行浅蓝 B8CCE4（themeFill accent1 tint66）、改焊前行浅红 E5B8B7（accent2 tint66）灰字 595959，接口名列保持白底；T2 带宽/T7 INL 已按此办理，T0/T1 旧配色 95B3D7/D99594 已统一换新。④ T2 改焊前 70 MHz 阻带抑制首次填入：-29.410/-29.414/-29.809/-29.955/-30.070 dB，来源为 gaihanqian_20260915 各通道带宽 run 逐点 CSV 的 70 MHz 点 RelativeDb（与报告改焊前行 30 MHz/带宽值逐位匹配验证）；结果说明同步改为同基准"改善约10 dB"。⑤ 报告编辑期间用户 Word 并发编辑：以用户最后保存版本为基 rebase 重放编辑脚本，交付前须重查文件 mtime 与写锁。

2026-09-17：新增 `CW_analysis/CW_513_ANALYSIS/128_hy/adc_bandwidth_analysis.m`，ADC128为用户确认的12 bit ADC，unsigned输入，采样率必须显式提供或交互填写。沿用公共带宽算法，全正正弦通过DC项拟合；未注册独立发布。7频点合成运行、DC平移不变性、交点、Nyquist拒绝和3文件checkcode通过；未验证实测CSV。证据位于 `F:/01_Laser/.codex_work/20260917-adc128-bandwidth`。

- 建档日期：2026-08-31
- 文档修订：2026-09-15
- 主分析库：`F:\01_Laser\code\matlab\513DIANXING_analysis\CW_analysis\CW_513_ANALYSIS`
- 当前数据根：`F:\01_Laser\0_20260727_513test\CW_Data\513_CW_DATA`
- 当前文档根：`F:\01_Laser\0_20260727_513test\03_CW测试\01_Documents_文档`

本文件汇总工程结构、器件配置和已知问题。具体测试条件仍需查看测试细则、原始数据、仪器设置和对应的 RTL/XDC、MATLAB 实现。文档与代码不一致时，先查明原因并修正，再交付正式结果。

## 工程结构

2026-09-09用户要求取消INL/DNL额外码端裁剪：AD2208、AD9245的 `marginCode` 均改为0；仍取有效记录拟合范围交集并限制合法码域，不放大到满量程。质量门槛和公式不变，原marginCode=1000的历史结果不覆盖。

### 2026-09-09 报告刻度更新

`CW_analysis/CW_513_ANALYSIS/_shared/+converter/+calibration/reportCalibration.m` 保存 `SZSD_YCQD测试结果__20260903.docx` 中20条刻度：AD2208五路、AD9245四路、DA766八路、AD677两路和DA9726 JG18斜率。采用独立刻度表，不采用噪声章节旧ADC系数。五器件private配置加载对应记录；2208 ILA已补JG19/JG24，2208和9245 PICO默认读取随代码提供的配置，仍可显式指定旧工作簿。2208 PICO的JG18高精度固定值保留。采样率和噪声算法未改。memory和AGENTS不发布。

本地高频ILA目录的 `JG19.csv` 表头为yb2208模块0（ADC1/JG15），不是模块2；不能按文件名判为JG19，需核对采集来源。

```text
513DIANXING_analysis/
  memory/
    PROJECT_MEMORY.md
    RESOURCE_INDEX.md
    SCRIPT_AUDIT_LEDGER.md
  CW_analysis/
    CW_513_ANALYSIS/
      README.md
      ARCHITECTURE.md
      METRICS.md
      2208_hy/
      9245_hy/
      677_hy/
      9726_hy/
      766_hy/
      _shared/+converter/
      noise_chain_hy/
      _templates/
      tests/
      tools/
```

正式源码位于五个器件目录、`_shared/+converter` 和PICO噪声模块 `noise_chain_hy`。`_release` 是生成物，现已与 `legacy` 一起移出日常运行目录，归档位置见后文。`Matlab_AND_ExampleData_lyp` 仅用于历史对比，不加入运行路径。

## 器件和入口状态

| 器件 | 正式入口范围 | 配置 | 当前结论边界 |
|---|---|---|---|
| AD2208/YB2208 | SFDR、输入频率响应、隔离度、`CodePp -> Vpp` 刻度及99%临界输入估计、INL/DNL、直接 ILA 噪声与 PICO 1 Hz 联合噪声；共7个单项入口 | `2208_hy/private/ad2208Config.m` | `releaseReady=true`；每项正式结论仍须核对需求、参考面和数据覆盖 |
| AD9245 | SFDR、输入频率响应、隔离度、`CodePp -> Vpp` 刻度及99%临界输入估计、INL/DNL、经 DA9726 JG18/G=128 链路折算的 1 Hz 输入等效噪声 | `9245_hy/private/ad9245Config.m`；噪声入口固定 JG18 刻度源 | `releaseReady=true`；噪声默认不扣 DA/Pico 本底，记录完整性、参考面或需求未确认时，不能判为正式满足 |
| AD677 | 输入频率响应、`CodePp -> Vpp` 刻度及99%临界输入外推；ILA噪声；经DA9726 JG18/G=128折算的PICO 1 Hz输入等效噪声；批处理和结果审计 | `677_hy/private/ad677Config.m` | `formalEnabled=false`；高阻信号源显示 Vpp 的板端参考面和终端未确认；噪声无正式限值；短PICO记录不能用于1 Hz ASD |
| DA9726 | DAC 刻度/正弦输出Vpp、输出噪声、隔离度；共3个单项入口 | `9726_hy/private/da9726Config.m` | `formalEnabled=false`；需求来源和参考条件未完全确认 |
| DA766 | DAC 通用/十六进制刻度、输出噪声、隔离度；共4个单项入口 | `766_hy/private/da766Config.m` | `formalEnabled=false`；需求版本存在冲突 |

当前不属于正式入口的内容：

- DA 相位噪声；
- DA 独立DC输出电压和DAC INL/DNL（正弦输出Vpp已由刻度脚本提供）；
- DA766 更新率/分辨率；
- AD677 的 SFDR、隔离度和 INL/DNL；
- 未进入五个器件目录和公共内核的历史 workflow。

## 公共内核

| 模块 | 责任 | 主要入口 |
|---|---|---|
| `converter.adc` | ADC 动态指标、带宽、隔离度、刻度、99%临界输入估计、INL/DNL、输入噪声和正弦/频率拟合 | `runSfdr`、`runBandwidth`、`runIsolation`、`runPowerScale`、`estimateCriticalInput`、`runInlDnl`、`runInputNoise` |
| `converter.dac` | Pico MAT 加载、正弦拟合、DAC 刻度、噪声和隔离度 | `runScale`、`runNoise`、`runIsolation` |
| `converter.io` | ADC CSV/Pico MAT、通道识别、文件名条件解析、文件选择和输出根解析 | `readAdcCsv`、`loadPicoMat`、`resolveOutputBase` |
| `converter.report` | 数值表和统一图片输出 | `writeTable`、`saveFigure`、`plot*` |
| `converter.runtime` | 运行配置、目录、日志、状态、哈希、清单和结果审计 | `createRun`、`finishRun`、`writeRunManifest`、`auditRun` |

发布包运行时，器件 `private/bootstrapRuntime.m` 优先解析包内 `internal/+converter`，否则使用开发库相邻 `_shared/+converter`；两者均不存在时应报“运行内核缺失”。

## 数据和输出约定

- 原始数据只读。
- 输入目录名为 `raw` 时，默认输出为与其同级的 `results`；其他输入目录默认输出为其内部 `results`。
- 用户显式提供输出目录时，以显式目录为准。
- 每次运行生成独立时间戳结果包。
- 最小证据包括：输入路径、大小、修改时间、SHA-256、运行配置、数值明细、摘要、MAT、图片、日志和状态。
- 旧文档中不带 `0_` 的测试路径已失效，不能继续引用。

## 测试和发布

测试入口：

- `tests/run_all_tests.m`：完整 MATLAB 测试集合。
- `tests/run_golden_regression.m`：黄金回归。
- `tests/run_portability_smoke.m`：迁移/独立运行冒烟测试。

当前可见测试证据：

- `tests/unit/adcCoreTest.m`
- `tests/unit/dacCoreTest.m`
- `tests/unit/ioUtilitiesTest.m`
- `tests/unit/ad677ContractTest.m`
- `tests/integration/ad9245WorkflowTest.m`
- `tests/integration/ad677WorkflowTest.m`
- `tests/integration/portabilityTest.m`
- `tests/golden/ad9245_x3g`

发布工具：

- `tools/buildDeviceRelease.m`：构建设备独立包。
- `tools/deviceReleaseRegistry.m`：器件发布注册。
- `tools/verifyDeviceRelease.m`：独立包静态、依赖和合成数据验证。

测试通过说明相应用例通过，不表示所有测量方法都已验证。公式、单位、参考面、数据选择和独立复算的检查情况见 `SCRIPT_AUDIT_LEDGER.md`。

## 已知不一致和待办

1. AD9245旧ILA数据为25 MHz，后续计划改为20 MHz。当前 `ad9245Config.m` 默认仍为25 MHz；实际用20 MHz采集的新数据需调整分析参数，旧数据继续用25 MHz。此前 `METRICS.md` 将旧ILA数据写成20 MHz有误，现已更正；ADC转换时钟20 MHz与旧ILA时钟25 MHz需分开记录。
2. AD2208 旧 README 曾引用不存在的旧测试根路径，现已改为当前 `0_20260727_513test` 数据根。
3. 代码默认目录名是 `results`，不是 `result`；显式指定目录除外。
4. DA9726/DA766 的 `formalEnabled` 关闭，不能仅凭数值低于限值就判为合格。
5. AD677 当前只有方法和数据处理入口，没有独立正式操作手册，正式合格判据也未确认。
6. 操作手册总索引仍是草案，所有 A/B/C/D 状态必须保留。
7. `C:\Users\86183\.codex\laser-fpga-profile.json` 的 `cw513_test_data_root` 应与本文件记录的当前数据根一致。

## 事实来源优先级

同一事实冲突时，按以下顺序处理：

1. 原始测量文件、仪器设置、manifest 和源文件哈希；
2. 当前器件配置及 `_shared/+converter` 可执行实现；
3. 当前有效测试细则和正式批准的需求；
4. 与当前固件匹配的 RTL/XDC/BIT/LTX 证据；
5. 当前操作手册索引指定的版本；
6. 测试报告和历史结果；
7. legacy、示例和旧 workflow。

采用与上述优先顺序不同的来源时，需写明原因，不能直接替换原记录。

## 维护规则

- 新增器件或指标：同步更新本文件、总 README、`ARCHITECTURE.md`、`METRICS.md` 和审计台账。
- 修改算法：同步更新测试、黄金基线和审计证据。
- 修改数据或文档根路径：同步更新本文件、相关 README 和本地维护配置。
- 调整操作手册状态：需核对总索引、适用条件、原始数据和结果记录。

## 2026-09-08 日常路径清理

历史实现 legacy/、生成发布副本 _release/、三个固定日期批次驱动和未被正式 CodePp→Vpp 流程引用的 codePpToInputPowerDbm.m 已移入 F:\01_Laser\research_assets\CW_513_ANALYSIS_archive\20260908。它们不再属于日常 MATLAB 运行区；逐文件哈希和恢复说明见该目录的 CLEANUP_RECORD.md 与 cleanup_manifest.csv。

converter.dac.loadPicoMat.m 因 tests/unit/dacCoreTest.m 直接调用而保留。noise_chain_hy/ 是当前 AD9245/AD2208 PICO 联合噪声链的一部分；清理前发现其工作树状态异常，已使用审计开始时的源码快照恢复。

## 2026-09-08 单项噪声入口与使用说明

- 2208直接ILA噪声改名为 `adc_ila_noise_analysis.m`，旧名不保留；新增 `adc_pico_noise_1hz_analysis.m`，零参数选择一份PICO MAT并确认接口，显式调用必须提供interface。
- PICO入口沿用当前noise_chain公式；AD2208使用的DA9726 JG18斜率固定为1.01451391294771e-4 V/CodePp，不查找或读取DAC刻度CSV。ADC刻度继续读工作簿。默认FPGA增益128、Hann/0.2 Hz/50%、不扣本底；记录固定刻度来源和入口/内核/输入SHA-256。共用噪声内核只加载_shared，不递归加载整个库。
- 2208/9245/9726/766分别有7/6/3/4个单项入口。四份README_先看.md逐入口说明签名、参数、选择和输出；当前DAC允许省略输出目录，2208隔离度第四参数按字段覆盖默认配置。
- 该变更没有修改数值公式、器件默认配置、动态范围算法或历史测试基线；测试与真实回归结果见本次SCRIPT_AUDIT_LEDGER记录。

## 2026-09-08 单项文件选择统一与GitHub发布

- 四器件20入口及677两个入口，零参数选择具体CSV/MAT；不再默认扫描全目录或使用固定文件列表。取消不创建结果；显式文件、接口和配对清单不弹窗。四份README、总README、ARCHITECTURE、METRICS与677说明已同步。
- 相对路径基于指定数据目录，绝对路径保留；检测重复输入和输出重名。默认输出为数据目录下results，直接raw目录使用其同级results（PICO2208保留原raw/results约定）；实际run目录带时间戳。选择框末尾目录分隔符已规范化。
- ILA2208使用单段Hann：welchSegmentCount=1、overlap=0、NFFT=131072；要求输入恰为131072点，不做分段平均。100MHz时频点间距762.939453125Hz；不是PICO的1Hz噪声。数值公式、动态范围、ADC INL/DNL和DAC隔离核心不重写。
- PICO2208 DAC固定系数1.01451391294771e-4，PICO9245独立固定1.014514e-4，均不以文件名推断接口；ADC刻度工作簿仍为外部依赖。
- 120项自动化测试、4项真实数据回归、3项固定系数测试通过；交互取消使用UI桩，不等于人工桌面交互或板级验证。证据：F:/01_Laser/0_20260727_513test/CW_Data/513_CW_DATA/results/file_selection_20260908_233612/VERIFICATION.md。
- 发布仓库为git@github.com:USTC0825HY/513_CW_MATLAB.git。发布范围为完整CW_513_ANALYSIS及配套说明/记忆，不含原始实测数据、输出结果或已移走历史入口；原MATLAB仓库的GitLab远端与无关修改保持不动。

## 2026-09-09 文档修订

已逐份修改发布库中的18份Markdown，简化重复提醒和修改过程描述，保留参数、公式、函数签名和原测试结论。代码未改，未重新运行MATLAB测试。私人代理规则文件不纳入发布，也不作为仓库内文档链接。

## 2026-09-09 DA刻度文件名兼容修复

- DA9726 DAC1_JG18当前刻度数据按已有2026-08-20成功结果恢复为16位十六进制CODE/COADE、`raw_unsigned_code`和1001000 Hz；MAT实际采样率仍从`Tinterval`读取。9个真实MAT复跑斜率为1.01451391294771e-4 V/code，与旧审核结果一致。
- DA766当前06_scale数据应使用`dac_scale_hex_analysis`。X7标准A批次与历史CH2/B批次均支持，但必须分开选择；两批分别以8点和5点复跑成功。误用十进制`dac_scale_analysis`会在创建结果前提示改用十六进制入口。
- 公共十六进制解析允许码值后带JG/CH/采样信息，同时保留分隔符约束，避免把`7FFF`局部误读。原始MAT未改。生产代码checkcode为0项，`dacCoreTest` 7/7通过；证据在`F:/01_Laser/.codex_work/20260909-dac-scale-code-parsing/VERIFICATION.md`。

## 2026-09-14 AD677 ILA与PICO噪声入口

- 新增 `677_hy/adc_ila_noise_analysis.m` 和 `adc_pico_noise_1hz_analysis.m`。ILA保留全部100 MHz抓取点，valid列只统计有效脉冲数和更新率；PICO按AD677—FPGA G=128—DA9726 JG18链路折算输入等效PSD/ASD。
- AD677噪声斜率固定在 `private/ad677Config.m`：677_1为1.536050e-4 V/code，677_2为1.695154e-4 V/code；DA9726固定使用JG18的1.01451391294771e-4 V/code。噪声入口不读取公共AD677报告刻度、外部工作簿或DAC结果CSV。
- PICO显式运行必须指定接口，采样率只取MAT的Tinterval或fs。默认0.2 Hz分辨率要求至少约5秒；现有约10 ms文件会在创建结果目录前被拒绝。没有正式限值，状态保持“暂不能判定”。
- 已补充定向集成测试、公共文件选择测试和文档。2026-09-14本机MATLAB R2025b启动阶段报文件系统一致性错误，测试与checkcode未实际运行，不能标记为通过。

## 2026-09-15 AD9245旧ILA SFDR抽样

- AD9245 SFDR对旧25 MHz ILA数据改为固定步长抽样：按 `1:5:end` 每5点保留1点，分析采样率为5 MHz，再使用既有周期Hann窗计算FFT；其他AD9245指标和其他器件不使用该规则。
- `ADC_SFDR_summary.csv`新增源/分析样点数、源/分析采样率、步长、抽样模式和结果用途。旧数据标记为“旧25 MHz ILA数据抽样估算”，频谱覆盖到2.5 MHz。
- 20 MHz同步采集必须同时设置源/分析采样率20 MHz和步长1；公共SFDR入口拒绝采样率与步长不一致的配置。
- 已补集成测试，但本机MATLAB R2025b仍在启动阶段报文件系统一致性错误，测试未实际运行。

## 2026-09-17 DA766噪声默认目录失效修复

公共 selectCaptureFiles 在文件列表为空、起始目录不存在时回退 pwd 并打开选择框；显式文件列表仍严格验证目录。DA766 README同步。MATLAB R2025b验证零参数取消、失效目录取消、选择后路径更新、显式错误路径拒绝以及checkcode通过（UI桩测试，未人工点击窗口、未重算真实噪声）。证据：F:/01_Laser/.codex_work/20260917-da766-path/matlab.log。未修改噪声公式或数据。


## 2026-09-17 MAT纯切分入口

split_dac_isolation_channels v0.2.0只切分A/B/C/D并记录接口、时基和哈希；移除驱动接口、目录频率、正弦拟合及配对模板生成。保留文件名JG顺序/显式channelMapping映射。真实JG25-1M目录中四通道文件单独切分4路、单D文件单独切分1路均通过；波形/时基/源哈希一致；checkcode零问题，3项相关回归通过（含另行显式构建配对后的隔离度计算）。证据：F:/01_Laser/.codex_work/20260917-jg25-isolation/pure_split.log。原始数据和历史结果不改，方法审计状态不升级。

## 2026-09-20 AD677刻度读取进度输出与多副本遮蔽排查

- `_shared/+converter/+adc/runPowerScale.m` 读取循环增加逐文件进度打印（正在读取 i/N、已读入行数）。起因：10个约7.9MB CSV 读取+拟合约10分钟无任何输出，用户两次误判卡死并中断（run目录无STATUS_*标记即为中断证据），实际管线完整可跑通。
- 实测回归：AD677 X3 1kHz 0.25–2.5Vpp 扫幅10点全部入标定，斜率1.5325135925e-4 Vpp/CodePp，截距0.0417323155 Vpp，R²=0.99999657；结果包 run_20260920_163743_power_scale（STATUS_SUCCESS）。
- 遮蔽风险记录：CW_513_CODE 为旧快照（缺 +io/parseVoltageVpp.m，runPowerScale 只认dBm文件名、ad677Config 为旧版），另有 D:\CW_analysis 旧库仅2208/9245。AD677 入口必须从 CW_513_ANALYSIS\677_hy 运行，否则路径解析到旧副本会报"没有可解析输入功率的 CSV 文件"。
- 遗留：CSV 表头为 adc1_data[15:0] 时 detectChannel 无法回映射，summary 的 Channel 标记 Unknown（数值不受影响）；本次通道为 X3→adc1_data(677_1)。

## 2026-09-20 readAdcCsv 性能修复（76s→0.85s/文件）

- 热点：含十六进制列的 ILA CSV 走 textscan 回退后对全部 21 列逐元素 str2double（约275万次，单文件76.3s，10文件一次分析11.6分钟）。计算本身（FFT/正弦拟合）每文件不足1s。
- 修复 `_shared/+converter/+io/readAdcCsv.m`：首行字段探测含 [a-fA-F] 字母则跳过必败的 dlmread；textscan 只解析需要的列（数据列+可选valid列，其余 %*s）；整数列用整串 sscanf 向量化，数据列保留旧的整列 hex2dec 语义（仅当全列纯hex字符）。textscan 对 %*s 跳过列不产生输出单元，转换循环必须用递增 token 索引而非列号（此坑已踩）。
- 回归：X3 0.25Vpp 单文件 read 76.31s→0.85s；全套10点分析 11.6min→40.4s（含MATLAB启动）；slope/intercept/R² 与旧版17位有效数字一致（0.00015325135925031594 / 0.041732315541242224 / 0.99999657033375233）。
- X13 刻度必须用 runOptions.adcDataColumn=12（adc2_data/677_2）；X13 CSV 第4列(adc1_data)为另一路且已到-32768满轨，按默认列解析会全部频点失配并报"标定点少于2个"。
- AD677 X3/X13 刻度与动态范围已填入电性加强件 20260920 报告 5.1/5.2（三段式 numId 30/31，复用 abstractNum 2，startOverride=1）。

## 2026-09-20 十六进制输入、方法门控与精简结果包

- 主库当前保留25个单项入口。ADC CSV统一由`readAdcCsv/resolveAdcInputRadix`解析`auto|hex|decimal`；auto不猜纯数字或无前缀歧义码。按器件位宽/码制转换，缺失、非法、非整数和超范围样点直接拒绝；实际进制、列、位宽和转换规则写入`evidence/input_decoding.csv`。
- 新成功运行根目录提供`结果汇总.xlsx`和PNG，完整CSV/MAT/FIG/配置/哈希/日志/状态放入`evidence`。工作簿是报告用字段选择层，不重新拟合；数值保持数值单元格，缺测留空。历史结果不迁移。
- SFDR修正THD符号与谱掩码；带宽增加时基/周期/Nyquist/有效点门控；ADC隔离度和INL/DNL增加正式有效性/通道覆盖限制；PICO变量、压缩MAT、噪声增益和积分覆盖已修正。9726/766噪声默认电压增益100，刻度和隔离度默认1；2208/9245动态范围算法未改。
- 真实AD677 X3十进制与只改变ADC列表示的十六进制副本结果逐字段一致，并与历史刻度一致：斜率1.5325135925031594e-4 Vpp/CodePp、截距0.041732315541242224 Vpp、R²=0.99999657033375233。9.918286837 Vpp临界输入是0.25～2.5 Vpp扫描外推，不能当实测点。
- 真实DA9726 JG18刻度复现历史：斜率1.01451391294771e-4 V/原始无符号码幅、截距-0.00772158623565433 V、R²=0.999984119899267；原始9个MAT哈希不变。负载/参考面仍不完整，正式状态保持暂不能判定。
- 可读审计报告和144脚本矩阵位于`CW_513_ANALYSIS/docs/20260920_revision`。本轮没有同步旧发布副本、CW_513_CODE/ZIP，没有提交或推送Git。
- AD9245真实黄金回归驱动已显式固定历史条件：十进制、25 MHz源采样率、SFDR步长1且分析采样率25 MHz。SFDR、带宽、隔离度、INL/DNL四入口均实际运行，最终因当前完整summary字段/状态与旧黄金CSV签名不同而报`converter:test:GoldenMismatch`。旧基线按要求未改，因此该项状态是“已运行、未通过旧签名”，不能写成回归通过；证据在`.codex_work/20260920-cw513-current-audit/implementation/golden_regression_2.log`。

2026-09-22：DA9726噪声入口显式路径跳过旧默认盘符查询，公共噪声添加阶段进度；JG18 20260922真实20秒MAT已成功分析，G=100后ASD约2.182275 µV/√Hz、1–100 kHz RMS约34.567572 µV。完整条件与边界见审计台账。本轮未提交推送。

## 2026-09-29 L盘20260928重测批处理：30个psdata→MAT导出、DA766四指标、2208隔离15MHz重跑、鉴定件报告20260928版

- **PicoScope psdata→MAT GUI 自动化（可复用流程，全部脚本在 `.codex_work/20260928-l-retest/`）**：核心坑有四。1) PicoScope 7 的 WPF 模态交互（工具栏保存按钮、格式下拉 popup）会被**持有活动 UIAutomation 会话的进程抑制**——点击进程必须零 UIA，所有 UIA 查询走即退子进程（uia_query.ps1 模式，export_batch.ps1 v3）。2) `GetCurrentThreadId` 在 kernel32 而非 user32（EntryPointNotFound→ForceForeground 静默失败→前台 False→点击被激活吞噬）。3) 该机 UIA 逻辑坐标→物理屏幕坐标恒为 ×2/3（150% DPI 小屏）：保存工具栏按钮 SaveDialog 中心≈(981,162)、文件类型行箭头≈(529,389)、格式列表第2行 MATLAB 文件≈(356,278)、保存按钮≈(236,672)，前提 SetWindowPos(101,101,1280,640) 归一化+SetForegroundWindow(AttachThreadInput 版)+travel/dwell 900ms（箭头 hover 显示才可点）。4) force-kill 触发应用恢复机制生成僵尸实例吞掉下一次启动的文件参数——kill 后必须循环清场到无 PicoScope 进程。多通道文件窗口最小 1536x960，Save 按钮位置随窗口宽度变化（用 UIA 子进程查 SaveDialog rect×2/3）。MAT 导出为 PicoScope v5 格式（A/B/C/D+Tinterval/Tstart/Length）。
- **2208 隔离度非交互调用**：adc_isolation_analysis 必须传 selectedFiles（非空跳过 radix prompt；batch 模式弹窗直接报错）+ inputRadix='decimal' + **drivenChannel 显式指定**（非交互时 config 默认 drivenChannel=ADC5_JG22，不显式会拿错驱动路）；isolationFrequencyHz 按误差通道实测口径（20260928 批次 jg15/19/22 为 15e6，jg17/24 为 1e6 原始有效）。新 run 落 F:\...\0928_test_data\2208\reset_isolation\，已同步 L 盘副本。
- **DA766 四指标（20260928 复测）**：三/四通道 psdata→MAT 不能直接进 766 入口（loadPicoMat 多变量报错；split_dac_isolation_channels 强制 JG\d+ 标签拒 X11-x）——用本地拆分（每变量存单通道 `<LABEL>__<src>.mat`，变量 A+Tinterval）后逐通道跑。噪声 hardwareGain=100（对齐改焊后批次 20260925_153117 run 的配置，虽然文件名无 MULT 标记）；刻度 tone=1525.879 Hz（refineSineFrequency(adcCode, 初值, sampleRate, 40, 8192)——注意参数序，cap.voltage 非 cap.waveform）；隔离度 tone=19836.39 Hz、56 对配对 manifest（跨文件 driven/victim 为既有口径，reference_plane 文案沿用）。
- **关键实测发现（报告已如实呈现）**：X11-5/6/7 改焊后输出形态变 0～10V 单极性（与加强件改焊后一致），刻度 k 减半≈1.56～1.58×10⁻⁴；三路相互隔离度 39.03～40.52 dB（2 处 <40 标红不满足，改焊前 127～163 dB），待结合 PICO 四通道同采串扰本底复核；噪声 3.85～4.39 µV/√Hz 较改焊前改善。
- **报告更新（鉴定件_SZSD_YCQD测试结果_20260928.docx，md5=2d916745350d80d5e16c5e251fb68a7b）**：SFDR 表 JG19 从 25MHz 单点重建为 11/12/13MHz 三点（vMerge restart/continue 模板克隆）；2208 隔离度矩阵换 15MHz 重跑值（全矩阵最差 90.85dB）；DA766 四表加状态/改焊情况列+改焊后蓝(B8CCE4)行在前+改焊前红(E5B8B7)灰(595959)行（改焊前行旧值必须独立填——先写新值再 deepcopy 会把新值带进旧行，此 bug 已修）；题注手输编号（非 SEQ 域）插新图后须按文档顺序全量重编号（整段文字重写进首 run 删其余 run，多 run 拆分编号必须整段重写）；表格行加 cantSplit 防跨页断行；行显式 tcW 与 tblGrid 列数不符会造成单行渲染错位缺格（清零 tcW+补 gridCol）。visual-judge 三轮验收 14 页全过。
- 本轮 L 盘原始 psdata 只读未动；新分析 run 全部落 L 盘数据目录旁 results/；2208 隔离度新 run 同步了 L 盘副本。旧报告 20260924 版已归档 archive_鉴定件历史/。

## 2026-09-29 split_dac_isolation_channels v0.3.0 升级：任意通道数+通用接口标签

- 用户授权的库改动（唯一文件 `9726_hy/split_dac_isolation_channels.m`，未提交 Git）：1) 标签校验从 `^JG\d+$` 放宽为 `^[A-Z][A-Z0-9]*([_-][A-Z0-9]+)*$`（JG15/X11-5/X77_8 均合法，仍要求文件内唯一）；2) 新增文件名 `CH<n>_<label>` 自动映射规则（优先于 JG 规则）：按 CH 序号 1..4 定位 A/B/C/D 变量，partial-channel（如仅 CH1+CH3）跨位不误配，token 内 `_` 归一为 `-`（X11_5→X11-5）；3) JG 旧规则保留为 fallback，行为不变。变量检测本就 isfield 自适应，1~4 通道 MAT 均可切分。
- 回归（`split_upgrade_test` 临时目录，已清理）：4通道真实 766 文件→X11-6/X77-8/X11-7/X77-7 正确按 A/B/C/D 对齐；3通道(缺D)、2通道(CH1+CH3 跨位)均正确；合成 JG18JG20noise 两通道→JG18/JG20 保持旧规则；无标签文件明确报错提示 channelMapping。checkcode 修掉 isscalar 提示（方括号拼接提示为原文件既有风格）。
- 由此 20260928 那批 X11-x 数据不再需要任务本地 localSplitMulti——库工具直接可用（自动 CH 标签或显式 channelMapping）。
