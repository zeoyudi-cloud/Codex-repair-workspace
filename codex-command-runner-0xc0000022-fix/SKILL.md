---
name: codex-command-runner.exe无法启用0XC0000022修复方案
description: 当 Windows 上的 Codex 或 IDE 扩展出现 codex-command-runner.exe 0xC0000022、PowerShell 中 codex 无法运行、默认沙盒卡住或 IDE 日志提示 local-environments is not supported in the extension 时使用。用于诊断 runner 是否损坏、区分扩展能力限制与本地环境问题、修复 PowerShell 入口和 Windows 默认沙盒配置，并给出稳定的终端调用方式。
---

# 适用场景

用户在 Windows 上遇到下列任一问题时使用本 skill：

- 弹窗提示 `codex-command-runner.exe` 无法启动，错误码 `0xC0000022`
- PowerShell 中运行 `codex` 报 `running scripts is disabled on this system`
- `codex sandbox windows ...` 或默认 CLI 沙盒卡住
- IDE 扩展日志出现 `local-environments is not supported in the extension`
- 不确定是 runner 本体坏了，还是 IDE 扩展不支持本地环境

# 快速结论规则

按下面顺序判断，避免误判：

1. 先直接运行 `codex-command-runner.exe`
如果输出 `runner: no request-file provided`，说明 runner 本体能启动，不是可执行文件损坏。

2. 再直接运行 `codex.exe --help`
如果能输出帮助，说明原生 CLI 本体正常。

3. 再看 IDE 日志
如果日志明确出现 `local-environments is not supported in the extension`，说明是扩展能力限制，不是本地 runner 故障。

4. 再看 PowerShell 中的 `codex`
如果 `Get-Command codex` 指向 `...AppData\Roaming\npm\codex.ps1`，且报执行策略错误，那么坏的是 PowerShell 入口，不是 CLI 核心。

5. 再看 `~/.codex/config.toml`
如果存在：

```toml
[windows]
sandbox = "elevated"
```

且 `codex sandbox windows ...` 卡住，则优先改成 `unelevated` 再测。

# 标准修复流程

## 1. 运行诊断/修复脚本

优先执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix_codex_env.ps1
```

如果只想看诊断，不改任何配置：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix_codex_env.ps1 -DiagnoseOnly
```

## 2. 结果解释

脚本会检查并修复这些项目：

- PowerShell 的 `codex` 是否落到 `codex.ps1`
- 当前用户执行策略是否阻止 `codex.ps1`
- `~/.codex/config.toml` 的 Windows 沙盒默认值
- `codex sandbox windows cmd /c echo ...` 是否通过
- `codex.exe`、`codex-command-runner.exe` 是否存在

## 3. 终端调用方式

默认建议优先级：

1. `codex`
前提是脚本已把 CurrentUser 执行策略修到 `RemoteSigned`。

2. `codex.cmd`
如果希望避开 `codex.ps1`，这是更稳定的 Windows 入口。

3. 原生 `codex.exe`
用于排除 npm 包装层问题。

常用命令：

```powershell
codex --version
codex.cmd --version
codex sandbox windows cmd /c echo ok
```

# 已知边界

- 如果 IDE 日志是 `local-environments is not supported in the extension`，本 skill 只能证明本地 CLI 没坏，不能让该扩展突然支持本地环境。
- 如果 `codex exec` 仍然超时，而 `codex sandbox windows ...` 已通过，优先怀疑模型连接、代理、防火墙、WebSocket/HTTP 流式连接，不是本地沙盒。
- 如果机器上同时存在 npm 版 `codex` 和 IDE 扩展自带 `codex.exe`，先确认当前终端实际命中了哪一套。

# 手动核对命令

需要人工复核时，只运行这些最小命令：

```powershell
Get-Command codex | Format-List Name,Source,Definition,CommandType
where.exe codex
codex --version
codex sandbox windows cmd /c echo ok
```

# 资源

- 诊断与修复脚本：`scripts/fix_codex_env.ps1`
