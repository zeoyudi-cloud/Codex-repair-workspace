---
name: GitHub仓库上传与操控最简流程
description: 当用户希望在 Windows 上由 agent 自动安装 git 和 gh、登录 GitHub、创建仓库、上传本地目录，或把内容上传到现有仓库的指定子目录时使用。适用于没有现成 git/gh、PowerShell 代理配置混乱、git push 因证书、凭据脚本、无交互终端或 PATH 问题失败，以及需要在上传前先做脱敏检查、自动泛化本机路径、再回退到 GitHub API 逐文件上传的场景。
---

# 适用场景

在这些情况下使用这个 skill：
- 用户要把本地目录上传到新的 GitHub 仓库
- 用户要把本地目录上传到现有 GitHub 仓库里的某个子目录
- 本机还没有 `git` 或 `gh`
- 需要由 agent 自动创建 GitHub 仓库
- `git push` 因代理、证书、交互提示、凭据脚本、无 TTY 或 PATH 配置失败
- 上传前需要先做脱敏检查，避免把本机绝对路径或本地私有目录一起发到 GitHub
- 希望用最短流程完成“建仓 + 上传”或“往现有仓库补一个子目录”

# 最短工作流

1. 检查 `git` 和 `gh`。
2. 没有就优先用 `winget` 安装；若系统里 `winget` 不在 PATH，尝试本地 WindowsApps 路径。
3. 清空坏掉的代理环境变量。
4. 用 `gh auth status` 检查登录。
5. 未登录则 `gh auth login --web`。
6. 上传前对源目录做脱敏检查。
7. 如果发现文档中有 `C:\Users\...`、`/Users/...`、`/home/...` 这类本机绝对路径，优先自动泛化成 `$HOME/...`。
8. 如果脱敏后仍存在高风险项，先停止上传并把问题列出来。
9. 如果目标仓库不存在，则创建仓库。
10. 如果用户指定的是现有仓库子目录，不要直接把整个源目录推到仓库根目录；优先用 GitHub API 上传到该子目录。
11. 如果是全新仓库或明确允许覆盖根目录，优先尝试 `git push`。
12. 只要 `git push` 因凭据脚本、无交互终端、证书或其它问题失败，就回退到 GitHub API 逐文件上传。

# 使用方式

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\upload_directory_to_github.ps1 -SourceDir "D:\path\to\folder" -Repo "owner/repo" -Visibility public
```

上传到现有仓库子目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\upload_directory_to_github.ps1 -SourceDir "D:\path\to\folder" -Repo "owner/repo" -RepoSubdir "my-skill"
```

如果只想看脱敏扫描结果：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\upload_directory_to_github.ps1 -SourceDir "D:\path\to\folder" -Repo "owner/repo" -SanitizeMode report
```

# 本次经验

- 现有仓库里已经有多个 skill 时，要把新 skill 放到独立子目录，不要覆盖仓库根目录。
- 有些 Windows 环境里 `gh` 已经登录成功，但 `git push` 仍会因为 `/dev/tty`、askpass、凭据脚本或无交互终端失败；这时直接走 GitHub API 更稳。
- 上传前先扫一遍绝对路径和本地 `.codex` 目录，可以显著减少把个人环境信息带进仓库的风险。
- skill 元信息文件如果要被 Codex 正常识别，`SKILL.md` 和 `agents/openai.yaml` 要保持 UTF-8 无 BOM。

# 资源

- 主脚本：`scripts/upload_directory_to_github.ps1`
