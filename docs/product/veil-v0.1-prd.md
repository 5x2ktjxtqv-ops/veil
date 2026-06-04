# Veil v0.1 PRD

状态：Draft, Phase 1 visual baseline frozen by VEL-012  
版本：v0.1  
日期：2026-05-08

## 1. 一句话定义

Veil 是一个面向现代 MacBook 屏幕边缘的极简视觉修正工具：先让刘海和屏幕四角看起来对齐、完整，再允许用户按需启用低干扰状态信号。

Veil 不追求把刘海变成玩具，也不追求把菜单栏变成仪表盘。它更像一层安静的屏幕边缘整理层：默认只做视觉贴合；用户需要时，才把刘海区域变成余光可读的状态层。

## 2. 产品身份

### 开源版产品形态

开源版 Veil 的身份不是某个人的 VPN / 私有服务监测器，而是一个低干扰的 macOS display-edge refinement tool，状态信号只是可选第二层。

产品核心应当保持稳定：

- Visual module：负责刘海融合、底部圆角补偿、显示器能力检测和像素贴合。
- HUD shell：负责状态区视觉、窗口层级、刷新节奏和低干扰呈现。
- Signal adapter：负责读取一个具体来源，并输出左右两个短值、严重度和可选指示点。
- User preference：负责启用、禁用、排序和授权这些 module / adapter。

公开 adapter 示例应只使用普适本地信号：CPU、内存、硬盘、被动网络、task-status file、Long Run keepalive state。Mullvad、model-growth、active VPN probe、CPU temperature、root-only system power policy mode 都属于 advanced/private integrations；它们可以用于内部验证，但不能作为开源产品的示例 adapter 或默认叙事。

### Veil 是什么

- 面向现代 MacBook 的屏幕边缘视觉修正层。
- 与刘海、屏幕圆角视觉融合的极简 overlay。
- 默认不监测任何个人工作流，先解决“四角看起来是否完整”的问题。
- 在用户启用后，用极低信息密度展示当前执行状态是否健康。
- 在用户启用后，用左右小灯显示 AI / background task 是否还在运行、已完成、失败或需要注意，以及 Long Run 是否仍在守护后台任务。
- 一个持续存在、低干扰、余光可读的状态显示区域。

### Veil 不是什么

- 不是 Dynamic Island 模仿品。
- 不是娱乐型刘海工具。
- 不是花哨动画组件。
- 不是默认启动的 iStat Menus 克隆。
- 不是超大系统监控面板。
- 不是什么都想展示的信息中心。
- 不是万能监控平台或插件容器。

## 3. 产品哲学

核心原则：先修正屏幕边缘，再只显示真正影响当前执行状态的信息。

Veil 的极简不是功能不足，而是产品特性。默认状态下，它不为满足好奇心而展示数据；启用状态信号后，它只帮助用户判断机器是否处在可继续工作的状态。

优先显示：

- 内存压力是否升高。
- Swap 是否持续增长。
- CPU 是否持续高压或进入热压力状态。
- 硬盘是否接近容量压力。
- 被动网络吞吐是否出现明显异常。

明确不显示：

- 天气。
- 新闻。
- 股票。
- AI 摘要。
- 社交通知。
- 日历流。
- 大量图表。
- 娱乐化状态或角色动画。

## 4. 目标用户与使用场景

目标用户：

- 长时间使用 macOS 工作的工程师、创作者和远程协作者。
- 经常依赖 VPN、SSH、Remote Coding、GitHub、API 请求、AI Streaming 的用户。
- 希望知道“当前机器是否还健康”，但不想打开大型监控工具的人。

核心场景：

- 用户在全屏 IDE 或浏览器中工作，需要通过余光知道内存和网络状态。
- 用户感觉终端、编辑器、AI 流式响应或 GitHub 请求变慢，需要快速判断问题来自内存压力、CPU 热压力、磁盘空间还是网络吞吐。
- 用户把 Claude Code、Codex、构建脚本或本地 AI 任务放到后台运行，前台看文档、视频或处理其他工作时，需要通过刘海侧边小灯知道任务是否完成或失败。
- 用户希望 Mac 在开盖状态下支撑本地 AI / background task 持续运行，同时允许屏幕黑掉或休眠显示器。
- 高级用户可以显式启用私有 workflow adapter，例如 Mullvad 或 local compact-status endpoint。

## 5. v0.1 产品目标

v0.1 只验证 Veil 是否能以原生、安静、低资源的方式跑起来。

必须完成：

- 刘海延展胶囊 `notch capsule` 作为默认视觉模块。
- 底部圆角补偿 `bottom-corner-mask` 作为默认视觉模块。
- 默认启动不进入 status telemetry。
- 用户启用 `--status-signals` 后，显示本地内存 / CPU / 被动网络状态。
- 用户启用 `--task-status-file` 后，读取一个本地 JSON task-status 文件并驱动左侧任务小灯。
- 用户启用 `--long-run` 后，持有进程生命周期 IOKit assertions，并用右侧小灯显示守护状态。
- 硬盘 / storage pressure 作为下一阶段公开本地 adapter。
- 用户显式 approval 后，才允许 advanced/private adapter 进入轮换。
- 低频轮询和低资源占用。

刻意不做：

- 动画系统。
- 主题系统。
- 设置页。
- 第三方插件系统。
- 大型 Dashboard。
- 全节点测速。
- 重型 Speedtest。
- 娱乐化 Dynamic Island 交互。

## 6. 信息架构

Phase 1 默认状态是纯视觉贴合：刘海延展胶囊和底部圆角补偿，不显示文字。

启用 `--status-signals` 后，刘海延展胶囊可以承载轮换状态：

```text
MEM 18G        CPU 18%
CPU 18%        NET 100M
NET 100M       DSK 42G
```

信息策略：

- 基础轮换只使用普适本地信号：MEM、CPU、NET，后续加入 DISK。
- 左侧小灯用于 task-status file：running / succeeded / failed / attention / stale。
- 右侧小灯用于 Long Run keepalive：asserted / verified / degraded / failed。
- 私有 adapter 只有显式启用后才追加到轮换。
- 中间覆盖物理刘海，不承载文字或图标。
- 健康态可省略 `MEM` / `CPU` / `NET` / `DSK` 标签，只显示数值；语义仍然固定。

Full HUD 不是默认常驻态，只作为 future expanded reference：

```text
RAM 18G   CPU 18%
SWAP 2.1G NET 100↓
DISK 42G  OK
```

未来 Hover 展开形态：

```text
RAM 18G
SWAP 2G
PRESSURE NORMAL
VPN FRA-WG
23ms
312 Mbps
```

后续版本可以探索点击 notch capsule 后向下展开更大信息面积，用于承载当前常驻空间放不下的本地细节或私有 adapter 诊断信息。默认 `320 x 32` 胶囊仍只显示当前最关键状态；节点候选排行、国家/城市筛选、endpoint latency、jitter/loss 和测速说明应放在显式启用的 advanced 展开态，不进入公开基础轮换 lane。

显示优先级：

1. 异常状态优先于正常数值。
2. 当前健康判断优先于历史统计。
3. 文本指标优先于图表。
4. 余光可读优先于信息完整。

## 7. 功能模块

### 模块 A：刘海延展胶囊视觉融合

目的：让 Veil 看起来像 macOS 原生状态层，而不是贴在屏幕上的 App 窗口。

显示内容：

- 覆盖刘海本体的黑色哑光 `notch capsule`。
- 胶囊左右翼区承载最小状态信息。
- 中间黑色覆盖区不承载文字、图标或状态点。
- 与菜单栏和刘海统一的黑色、哑光、低对比视觉。

不做什么：

- 不做多主题系统。
- 不做霓虹、复杂渐变或 AI 风背景。
- 不做高透明玻璃拟态。
- 不做壁纸管理工具。
- 不把状态层扩展成页面级 Dashboard。
- 不把整条黑色顶栏融合作为 Phase 1 默认方案。

成功标准：

- 在刘海屏上，HUD 与刘海区域自然融合。
- 用户不会感觉它是一个突兀的悬浮窗。
- 胶囊不会让整条屏幕顶部看起来像加厚边框。
- 默认实现与 `StatusHUDConfiguration.productionCompact = .notchCapsule` 一致。
- 全屏和普通桌面模式下都不遮挡关键操作区域。

### 模块 B：Overlay 引擎

目的：提供稳定、低干扰、接近系统层的 HUD 承载能力。

显示内容：

- 水平居中覆盖刘海的 HUD 胶囊。
- 默认固定在低信息密度尺寸内。
- 未来允许 hover 展开，但 v0.1 不要求实现。

不做什么：

- 不做可拖拽组件系统。
- 不做复杂窗口布局编辑器。
- 不做 Dynamic Island 式大面积展开动画。
- 不做通知中心替代品。

成功标准：

- HUD 可以稳定悬浮在预期位置。
- 默认 click-through，不干扰用户点击。
- 低 CPU、低 RAM，不成为新的系统负担。
- 为后续 fullscreen、多显示器、睡眠恢复留下清晰实现边界。

### 模块 C：内存生命体征

目的：判断机器是否进入压力状态，帮助用户解释卡顿、构建变慢、编辑器无响应等问题。

显示内容：

- 当前 RAM 使用量，例如 `RAM 18G` 或 `RAM 18.2G`。
- 当前 Swap 使用量，例如 `SWAP 2.1G`。
- 未来可显示内存压力，例如 `PRESSURE HIGH`。

不做什么：

- 不做复杂历史图表。
- 不展示每个进程的内存排名。
- 不做内存清理按钮。
- 不诱导用户手动释放内存。
- 不把内存模块扩展成完整 Activity Monitor。

成功标准：

- 用户能在一眼内判断内存是否可能影响当前工作。
- Swap 增长能被明确暴露。
- 正常状态保持安静，高压力状态有克制但明确的提示。
- 数据采集低频、低资源，不因监控本身增加压力。

### 模块 D：Mullvad 当前状态

目的：判断 VPN 与当前网络执行质量，而不是管理整个 VPN 世界。

显示内容：

- 连接状态：connected、connecting、disconnected、error 或 unknown 的简化表达。
- 当前国家或城市，例如 `VPN FRA`。
- 当前节点或 relay 信息，在空间允许或 hover 展开时显示。
- 当前延迟，例如 `23ms`。
- 当前下载速度估算，例如 `312↓` 或 `312 Mbps`。

不做什么：

- 不做全节点测速。
- 不做大规模 benchmark。
- 不做高频自动切换节点。
- 不 reverse engineering Mullvad。
- 不替代 Mullvad 官方 App。
- 不做复杂 VPN 配置管理。

后续候选：在明确用户触发的点击展开态中提供 Mullvad 节点选择辅助。第一阶段宜保持只读或近只读：读取 relay metadata，对用户选择的国家/城市候选做低并发 endpoint latency / jitter / loss 排行，并清楚标注它不是真实 VPN throughput。真正逐节点吞吐测速需要切换 relay 和产生测速流量，必须作为强确认的手动 benchmark，而不是默认 HUD 行为。

成功标准：

- 用户能快速判断当前 Mullvad 是否连接。
- 用户能快速判断当前节点是否健康。
- 断开、错误、延迟异常时状态表达清晰。
- 通过 Mullvad CLI 获取状态，保持实现边界干净。

### 模块 E：轻量网络吞吐估算

目的：补充 VPN 状态，让用户知道当前是否有明显数据流动。

显示内容：

- 当前下载速度估算，例如 `312↓`。
- 未来可在展开态显示上传速度。

不做什么：

- 不做 Speedtest 风格测速。
- 不跑满带宽。
- 不持续制造网络流量。
- 不展示复杂吞吐曲线。

成功标准：

- 当前下载速率能以轻量方式估算。
- 采样不显著影响网络和电量。
- 数值用于健康判断，而不是精确测速承诺。

### 模块 F：网络稳定性（Phase 3 候选）

目的：判断网络是否“抖”，而不只是判断网络是否“慢”。

显示内容：

- 丢包率，例如 `LOSS 3%`。
- 不稳定提示，例如 `UNSTABLE`。
- 未来可展示短窗口内的延迟波动。

不做什么：

- 不做大型网络诊断平台。
- 不做链路拓扑分析。
- 不做持续重型测速。
- 不对所有 App 做流量监控。
- 不默认采集敏感网络内容。

成功标准：

- SSH、Remote Coding、AI Streaming、GitHub、API 请求异常时，用户能快速识别网络抖动可能性。
- 检测方式轻量，例如 ping、TCP connect timing、短窗口稳定性采样。
- 状态表达保持克制，只在不稳定时提升可见度。

## 8. 禁止范围

以下内容不进入 Veil 的产品范围，v0.1、Phase 2、Phase 3 均默认禁止，除非后续 PRD 明确改写产品边界：

- 天气。
- 新闻。
- 股票。
- 社交通知。
- 邮件通知。
- 日历通知流。
- AI 摘要流。
- 大 Dashboard。
- 娱乐化 Dynamic Island。
- 音乐歌词和媒体控制中心。
- 大量动画、角色、徽章或游戏化反馈。
- 插件市场。
- 万能菜单栏替代品。
- 完整系统监控套件。

判断规则：如果一个功能不能帮助用户判断当前机器、VPN 或网络是否仍适合继续工作，就不应该进入 Veil。

## 9. 视觉设计语言

关键词：

- 黑色。
- 克制。
- 哑光。
- 安静。
- 原生。
- 基础设施感。
- HUD 感。
- 非娱乐化。

视觉原则：

- 以黑色和低对比文字为主。
- 默认使用 notch capsule 左右翼布局；展开态可使用紧凑单行或双行布局。
- 使用少量状态色，只表达异常等级。
- 默认状态不吸引注意。
- 异常状态只提高必要可见度，不制造警报感。

避免：

- 霓虹风。
- 复杂渐变。
- 大量动画。
- AI 风 UI。
- 过度玻璃拟态。
- 大圆角卡片堆叠。
- 营销页式视觉表达。

## 10. 技术路线

推荐技术栈：

- Swift。
- SwiftUI。
- AppKit，必要时桥接。

原因：

- 原生性能更好。
- 更适合处理刘海和多屏环境。
- 更容易控制低资源占用。
- 更适合 fullscreen、click-through、窗口层级等系统行为。

数据采集边界：

- 内存：`host_statistics64`、`vm_statistics64`、`ProcessInfo`。
- Mullvad：只在用户 approval 后通过 `mullvad status` 获取信息；`mullvad relay list` 仍需额外谨慎。
- 网络：默认使用接口计数器；ping 或 TCP connect timing 只在 approval 后用于当前节点轻量判断。

禁止实现方式：

- 不 reverse engineering Mullvad。
- 不使用重型测速服务作为默认采样。
- 不通过高频轮询换取视觉实时感。
- 不采集不必要的网络内容或用户隐私数据。

## 11. 系统架构

### 第一层：视觉融合层

职责：

- `notch capsule` / 刘海延展胶囊视觉基线。
- 刘海视觉覆盖。
- 壁纸圆角协调。
- 为左右翼 RAM / VPN 提供原生感黑色背景。

参考方向：

- TopNotch。
- Forehead。

### 第二层：Overlay 引擎

职责：

- 悬浮窗口。
- 透明层。
- 刘海定位。
- click-through。
- fullscreen 兼容。
- 未来 hover 展开。

参考方向：

- TheBoringNotch。
- Atoll。

### 第三层：数据提供层

职责：

- 内存状态采样。
- Mullvad 状态采样。
- Relay 延迟探测。
- 轻量吞吐估算。
- 未来网络抖动和丢包检测。

参考方向：

- Stats。
- iStat Menus 的采集思路。

注意：可以学习这些项目的架构和系统 API 使用方式，但不要照搬 UI 风格，不要 copy paste 克隆。

## 12. Phase 边界

### Phase 1：原型验证

目标：最快跑起来，证明 Veil 的产品形态成立。

包含：

- notch capsule / 刘海延展胶囊 overlay。
- RAM 显示。
- Swap 显示。
- Mullvad 连接状态显示。
- 当前节点国家、城市或 relay 简化显示。
- 当前延迟显示。
- 当前下载速度轻量估算。

不包含：

- 动画。
- 主题系统。
- 设置页。
- 插件系统。
- hover 展开。
- 多节点测速。
- 自动节点切换。
- 大型网络稳定性诊断。

Post-v0.1 记录：多节点测速/排行不进入 Phase 1，但可作为点击展开的 Mullvad 诊断面板候选。该面板应优先显示少量可行动结果，而不是把大量 relay 列表挤进刘海常驻空间。

Phase 1 成功标准：

- 用户运行后能看到水平居中覆盖刘海的稳定胶囊 HUD。
- HUD 能显示内存和 Mullvad 当前状态。
- App 不明显增加 CPU、内存或网络负担。
- 产品气质成立：它像系统状态层，而不是玩具组件。

### Phase 2：稳定性

目标：让 Veil 从可运行原型变成可长期驻留工具。

包含：

- fullscreen 兼容。
- 睡眠恢复。
- 多显示器行为。
- 低 CPU 优化。
- 低 RAM 优化。
- 开机启动。
- click-through 完善。
- 异常状态恢复策略。

不包含：

- 新增大量信息模块。
- 大 Dashboard。
- 插件系统。
- 娱乐动画。
- 节点 benchmark 平台。

Phase 2 成功标准：

- Veil 可以长时间运行而不打扰用户。
- 切换全屏、外接显示器、睡眠唤醒后状态可靠。
- 资源占用足够低，不需要用户关注 Veil 自身。

### Phase 3：精修

目标：在不破坏低信息密度的前提下增强可读性和异常判断能力。

可能包含：

- 微动画。
- hover 展开。
- packet loss。
- 网络抖动检测。
- 更精确的内存压力表达。
- 更好的异常状态提示。

仍然禁止：

- 天气、新闻、股票、社交通知。
- 大 Dashboard。
- 娱乐化 Dynamic Island。
- 大量图表。
- 插件市场。
- 复杂主题系统。

Phase 3 成功标准：

- 信息更清楚，但默认状态仍然安静。
- 展开态只补充诊断，不变成监控面板。
- 异常更容易被发现，正常更容易被忽略。

## 13. 验收标准

文档验收：

- 后续设计和开发可以直接根据本文判断功能是否进入范围。
- 每个功能模块都有显示内容、不做什么、成功标准。
- Phase 1、Phase 2、Phase 3 的边界清晰。
- 禁止范围明确包含天气、新闻、股票、社交通知、大 Dashboard、娱乐化 Dynamic Island。
- 文档保留 Veil 的克制感，不把它写成普通监控工具说明书。

产品验收：

- 用户平时几乎感觉不到 Veil 存在。
- 一旦系统异常，用户能立刻注意到 Veil 的状态变化。
- HUD 始终保持低信息密度。
- Veil 不与菜单栏、通知中心、Activity Monitor、Mullvad 官方 App 争夺职责。

## 14. 最终产品判断

Veil 应该像覆盖在机器上的一层薄薄状态层，安静地暴露系统生命体征。

它不是玩具，不是仪表盘，也不是炫技 UI。

它是给长期生活在电脑里的人使用的安静 HUD。
