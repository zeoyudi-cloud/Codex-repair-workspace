# GitHub 仓库上传与操控最简流程

这是一个面向 Windows + Codex/Agent 的最小 GitHub 上传 skill。
它解决的不是“怎么写代码”，而是“怎么把本地目录可靠地上传到 GitHub”，包括：
- 自动安装 `git`
- 自动安装 `gh`
- 检查并完成 GitHub 登录
- 创建仓库
- 初始化本地 git 仓库
- 优先尝试 `git push`
- `git push` 失败时自动回退到 GitHub API 上传
- 把内容上传到现有仓库的指定子目录

## 适用场景

- 机器刚装好，没有 `git` 或 `gh`
- PowerShell 代理环境很乱
- `git push` 因证书、prompt script、凭据、无交互终端或网络问题失败
- 需要把一个 skill 或目录补充进已有 GitHub 仓库的某个子目录
- 想让 agent 以后直接复用这条最简流程

## 目录结构

- `SKILL.md`
- `scripts/upload_directory_to_github.ps1`

## 直接运行

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\upload_directory_to_github.ps1 -SourceDir "D:\path\to\folder" -Repo "owner/repo" -Visibility public
```

上传到现有仓库子目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\upload_directory_to_github.ps1 -SourceDir "D:\path\to\folder" -Repo "owner/repo" -RepoSubdir "my-skill"
```

## 作为 Codex skill 安装

把整个 `github-repo-upload-minimal` 文件夹复制到：

```text
~/.codex/skills/
```

## 更新日志

### 2026-03-14

- 新增 `-RepoSubdir` 参数，支持把内容上传到现有仓库的指定子目录。
- 优化回退逻辑：当 `git push` 因 `/dev/tty`、askpass、凭据脚本或无交互终端失败时，自动回退到 GitHub API 逐文件上传。
- 改进 `winget` 发现逻辑：若 `winget` 不在 PATH，尝试从本地 WindowsApps 路径查找。
- 补充经验说明：已有多个 skill 的仓库应以子目录方式新增 skill，避免覆盖仓库根目录。
- 补充编码经验：Codex skill 的 `SKILL.md` 与 `agents/openai.yaml` 应保持 UTF-8 无 BOM，避免 skill 在列表中不显示。