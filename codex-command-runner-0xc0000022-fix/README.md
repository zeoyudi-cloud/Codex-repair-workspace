# codex-command-runner.exe 无法启用 0xC0000022 修复方案

这是一个适用于 Windows 的 Codex 修复 skill。它既可以直接当脚本包运行，也可以作为标准 Codex skill 安装到本地。

## 适用场景

- 启动 Codex 或 IDE 扩展时弹出 `codex-command-runner.exe` 错误，错误码为 `0xC0000022`
- 在 PowerShell 中运行 `codex` 失败，并提示 `running scripts is disabled on this system`
- `codex sandbox windows ...` 异常，默认沙盒卡住或无响应
- IDE 日志出现 `local-environments is not supported in the extension`
- 不确定问题到底在 runner、PowerShell 入口、CLI 配置，还是 IDE 扩展能力限制

## 目录结构

- `SKILL.md`
  Codex skill 入口说明
- `scripts/fix_codex_env.ps1`
  可直接运行的 PowerShell 诊断/修复脚本

## 使用方式

### 方式 1：直接当修复脚本运行

适合只想快速修机器的用户。

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix_codex_env.ps1
```

只诊断，不修改配置：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix_codex_env.ps1 -DiagnoseOnly
```

### 方式 2：作为 Codex skill 安装

适合希望以后在自己的 Codex 环境里长期复用的人。

把整个文件夹 `codex-command-runner-0xc0000022-fix` 放到：

```text
~/.codex/skills/
```

Windows 通常对应：

```text
C:\Users\<你的用户名>\.codex\skills\
```

放好后，Codex 在遇到相关问题时就可以触发这套 skill。

## 这个 skill 解决什么

- 诊断 `codex-command-runner.exe` 是否真的损坏
- 识别 `codex` 是否被 PowerShell 解析到 `codex.ps1`
- 修复当前用户的 PowerShell 执行策略为 `RemoteSigned`
- 修复 `~/.codex/config.toml` 中不合适的 Windows 默认沙盒配置
- 验证 `codex sandbox windows ...` 是否恢复可用
- 帮助区分“本地 CLI 问题”和“IDE 扩展不支持本地环境”

## 已知边界

- 如果 IDE 日志明确写了 `local-environments is not supported in the extension`，说明该扩展本身不支持本地环境调用，这不是本 skill 能直接改变的。
- 如果 `codex exec` 仍然超时，而 `codex sandbox windows ...` 已经正常，优先怀疑网络、代理、防火墙或流式连接问题，而不是本地沙盒。

## 分享建议

如果你要发给别人，直接分享整个文件夹：

- `README.md`
- `SKILL.md`
- `scripts/fix_codex_env.ps1`

这样对方既能直接运行，也能安装为 skill。
