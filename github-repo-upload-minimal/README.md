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

## 适用场景

- 机器刚装好，没有 `git` 或 `gh`
- PowerShell 代理环境很乱
- `git push` 因证书、schannel、prompt script、凭据、网络问题失败
- 想让 agent 以后直接复用这条最简流程

## 目录结构

- `SKILL.md`
- `scripts/upload_directory_to_github.ps1`

## 直接运行

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\upload_directory_to_github.ps1 -SourceDir "D:\path\to\folder" -Repo "owner/repo" -Visibility public
```

## 作为 Codex skill 安装

把整个 `github-repo-upload-minimal` 文件夹复制到：

```text
~/.codex/skills/
```

然后让 agent 执行类似请求：

```text
把本地目录 X 上传到 GitHub 仓库 Y，如果 git push 失败就改用 API 上传。
```
