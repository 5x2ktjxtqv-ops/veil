# Mullvad Read-Only Status Smoke Plan

状态：计划，未运行  
任务：VEL-018  
日期：2026-05-09

## 目标

在真正授权 `mullvad status` 前，先冻结一次最小、可撤销、只读的 smoke 执行方案。

本文件只定义下一任务如何请求用户 approval 后执行，不代表本任务已经执行 smoke。本任务不得启动 Veil、不得启动 overlay、不得执行 Mullvad CLI、不得 ping、不得做 TCP timing 或任何网络探测。

## 前置条件

下一任务执行 smoke 前必须同时满足：

- 工作区干净；如有无关改动，先停下确认。
- `pgrep -x Veil` 无输出，确认没有残留 `Veil` 进程。
- 三项验证通过：
  - `swift build`
  - `swift test`
  - `swift build -c release`
- 用户明确批准本次只读 smoke 后才能运行；approval 只覆盖本次启动周期内已说明的低频只读读取和短 ping，不跨启动持久化，不覆盖新命令类型。

建议提问文本：

```text
我需要先确认：这个 smoke 会启动 Veil notch capsule overlay 约 30-60 秒，并在本次运行内允许只读执行 `mullvad status`，若 Mullvad 已 connected，会对当前 relay 或 visible endpoint 做低频短 ping；不会 connect/disconnect/reconnect、不会切 relay、不会改 DNS/tunnel/route/proxy。是否继续？
```

## 计划命令

最小执行命令：

```sh
swift run Veil -- --approve-mullvad-readonly
```

`--approve-mullvad-readonly` 会同时打开本次运行的 status signal layer。若只验证本地非 Mullvad 信号，应改用 `--status-signals --deny-mullvad-readonly`。

更保守窗口：

- 启动后预计观察 30-60 秒。
- 观察到一次 status 和最多一到两次 HUD 刷新即可停止。
- 使用 `Ctrl-C` 停止前台 `swift run`。
- 结束后确认 `Veil` 窗口和进程均已清空。

## 会发生什么

- App 会因本次 Mullvad approval 启动真实 live telemetry 路径和 notch capsule overlay。
- 使用 `--approve-mullvad-readonly` 时，Veil 本次运行直接进入 approved，不再弹出 Veil 自己的 approval prompt。
- 如果改为不传 `--approve-mullvad-readonly`，需要显式传入 `--prompt-mullvad-approval` 或设置 `VEIL_PROMPT_MULLVAD_APPROVAL=1`，App 才会在启动后弹出 approval prompt，由用户选择本次是否允许只读读取。
- App 会以低频执行 `mullvad status`；当前实现节流约为每 15 秒一次。
- 若状态为 connected，App 会尝试对当前 relay host 或 visible endpoint 做短 ping；当前实现节流约为每 30 秒一次，单次短超时。
- HUD 右翼在 approval 后可显示当前 location，例如 `FRA`，并在可用时显示 latency。

## 不会发生什么

本 smoke 的 approval 不允许以下行为：

- 不执行 `mullvad connect` / `mullvad disconnect` / `mullvad reconnect`。
- 不切换 Mullvad relay。
- 不修改 DNS、tunnel、route、proxy、防火墙或系统网络设置。
- 不执行 `mullvad relay list`。
- 不做 TCP timing。
- 不查询公网 IP，不请求 IP echo 服务。
- 不做 Speedtest、fast.com、iperf 或任何吞吐压力测试。
- 不读取 Mullvad 账号、token、密钥、配置目录、日志目录或诊断包。
- 不重启 Mullvad App、daemon、system extension 或相关服务。

## 观测项

运行中只记录必要、脱敏的现象：

- HUD 右翼是否显示 location，例如 `FRA`；记录时只写短 location code，不写完整出口 IP。
- 是否出现 latency；记录数值区间即可，避免记录完整 relay host 或 visible IP。
- HUD 是否保持 notch capsule，没有退回 full HUD / compact bar。
- `CGWindowList` 观察到的 Veil window bounds 是否仍合理；当前设计尺寸为 `320 x 32`，允许因屏幕几何有小幅差异。
- 是否出现非预期 approval prompt 或额外窗口。
- 结束后 Veil 窗口数量是否为 `0`。
- 结束后 `pgrep -x Veil` 是否无输出。

## 中止条件

出现以下任一情况立即停止本次 smoke，并记录原因：

- 出现非预期 Mullvad prompt、系统权限 prompt 或额外授权请求。
- HUD 位置异常，例如偏离 notch capsule 区域、遮挡菜单栏关键区域、落到错误显示器或 bounds 明显异常。
- 用户感知到网络异常、VPN 异常、连接中断、DNS/路由/代理异常或工作流被打扰。
- 观察到任何可能改变 Mullvad 状态的迹象。
- 用户要求停止。

停止动作：

- 对前台 `swift run Veil -- --approve-mullvad-readonly` 发送 `Ctrl-C`。
- 停止后只做窗口/进程清理确认，不补跑 Mullvad CLI、ping、TCP timing 或网络探测。

## 记录模板

```md
## YYYY-MM-DD Mullvad Read-Only Status Smoke

- run command:
- start time:
- end time:
- approval scope:
- observed status:
- observed HUD right wing:
- observed latency:
- CGWindowList bounds:
- whether Mullvad state changed:
- unexpected prompts:
- abort reason, if any:
- cleanup confirmation:
- validation status:
```

填写要求：

- `approval scope` 必须写明是 per-run、read-only、只覆盖 `mullvad status` 和 connected 时的当前 relay/visible endpoint 短 ping。
- `observed status` 只写 connected/disconnected/error/unknown 这类结构化状态。
- `whether Mullvad state changed` 应为 `no observed change`，除非用户明确报告了变化；如果有变化，立即停止并升级处理。
- `cleanup confirmation` 必须包含窗口清空和 `pgrep -x Veil` 无输出。

## 本计划编写时的非执行确认

创建本计划时没有启动 Veil，没有启动 overlay，没有执行 Mullvad CLI，没有执行 ping，没有做 TCP timing、公网 IP 查询、Speedtest 或其他网络探测。
