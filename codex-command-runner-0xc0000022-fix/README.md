# codex-command-runner.exe 无法启用 0xC0000022 修复方案

这是一个面向 Windows 用户的修复包，用于排查和修复 Codex 在本地环境中的常见启动问题。

## 适用场景

- 启动 Codex 或 IDE 扩展时弹出 `codex-command-runner.exe` 错误，错误码为 `0xC0000022`
- 在 PowerShell 中运行 `codex` 失败，并提示 `running scripts is disabled on this system`
- `codex sandbox windows ...` 能力异常，默认沙盒卡住或无响应
- IDE 日志出现 `local-environments is not supported in the extension`
- 不确定问题到底在 runner、PowerShell 入口、CLI 配置，还是 IDE 扩展能力限制

## 这个修复包解决什么

- 诊断 `codex-command-runner.exe` 是否真的损坏
- 识别 `codex` 是否被 PowerShell 解析到 `codex.ps1`
- 修复当前用户的 PowerShell 执行策略为 `RemoteSigned`
- 修复 `~/.codex/config.toml` 中不合适的 Windows 默认沙盒配置
- 验证 `codex sandbox windows ...` 是否恢复可用
- 帮助区分“本地 CLI 问题”和“IDE 扩展不支持本地环境”

## 已知边界

- 如果 IDE 日志明确写了 `local-environments is not supported in the extension`，说明该扩展本身不支持本地环境调用，这不是本修复包能直接改变的。
- 如果 `codex exec` 仍然超时，而 `codex sandbox windows ...` 已经正常，优先怀疑网络、代理、防火墙或流式连接问题，而不是本地沙盒。

## 目录结构

- `skill/`
  - 原始 skill 说明
- `scripts/`
  - 可直接运行的 PowerShell 修复脚本

## 使用方法

进入本目录后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix_codex_env.ps1
```

如果只想看诊断结果，不修改任何配置：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix_codex_env.ps1 -DiagnoseOnly
```

## 分享建议

如果你要发给别人，建议直接分享整个目录：

- `README.md`
- `skill/SKILL.md`
- `scripts/fix_codex_env.ps1`

这样别人既能看场景说明，也能直接运行脚本。
