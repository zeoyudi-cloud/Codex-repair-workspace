---
name: GitHub仓库上传与操控最简流程
description: 当用户希望在 Windows 上由 agent 自动安装 git 和 gh、登录 GitHub、创建仓库、上传本地目录、以及在 git push 失败时通过 GitHub API 回退上传文件时使用。适用于没有现成 git/gh、PowerShell 代理配置混乱、git 推送受证书或提示脚本影响的场景。
---

# 适用场景

在这些情况下使用本 skill：

- 用户要把本地目录上传到新的 GitHub 仓库
- 本机还没有 `git` 或 `gh`
- 需要由 agent 自动创建 GitHub 仓库
- `git push` 因代理、证书、交互提示、PATH 或凭据配置失败
- 希望用最短流程完成“建库 + 上传”

# 最短工作流

1. 检查 `git` 和 `gh`
2. 没有就用 `winget` 安装
3. 清空坏掉的代理环境变量
4. `gh auth status` 检查登录
5. 未登录则 `gh auth login --web`
6. 初始化本地 git 仓库并提交
7. `gh repo create`
8. 优先 `git push`
9. 失败则用 GitHub API 逐文件上传

# 使用方式

## 安装成 skill

把整个目录放到：

```text
~/.codex/skills/github-repo-upload-minimal
```

## 直接运行脚本

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\upload_directory_to_github.ps1 -SourceDir "D:\path\to\folder" -Repo "owner/repo" -Visibility public
```

# 资源

- 主脚本：`scripts/upload_directory_to_github.ps1`
