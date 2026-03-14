---
name: 角色存档工坊
description: 用于本地创建、选择、激活和维护角色卡与私有记忆档案。适用于想在 Codex 会话间延续不同角色设定，但又希望角色数据只保存在本地、不随 skill 一起分发的场景。也适用于新对话里先发“你好”，先用文字选择角色，再按角色继续协作的场景。
---

# 角色存档工坊

在这些情况下使用这个 skill：

- 用户想创建、编辑、选择或切换本地角色
- 用户在新对话里先发“你好”，希望先看文字角色列表再确认绑定
- 用户想打开角色管理前端界面
- 用户想读取当前激活角色并按该角色继续协作
- 用户想把角色记忆继续保存在本地，而不是上传到 GitHub
- 用户提到“记忆重点确认”或想调整某个角色以后更该记住什么
- 用户希望每条记忆都带事件发生时间，方便回顾前后顺序

# 默认使用流程

1. 如果用户在新对话先发“你好”，先调用 `scripts/list-role-profiles.ps1 -AsJson`，只读角色列表，不先创建 session。
2. 用文字列出角色，允许用户直接回复角色名、编号或 ID。
3. 同时提示：发送“新建角色”或“角色工坊”可打开本地前端界面。
4. 只有当用户真正选中角色时，才运行 `scripts/ensure-role-session.ps1` 创建或确认本地 session。
5. 然后运行 `scripts/activate-role.ps1 -SessionId <id>` 把角色绑定到当前对话。
6. 之后在这个对话里读取角色时，优先运行 `scripts/get-active-role.ps1 -SessionId <id>`，不要只读全局激活角色。
7. 往当前对话绑定角色写记忆时，优先运行 `scripts/add-memory-item.ps1 -SessionId <id>`。
8. 调整当前对话绑定角色的记忆重点时，优先运行 `scripts/update-memory-focus.ps1 -SessionId <id>`。
9. 做增量记忆总结前，先运行 `scripts/get-session-summary-scope.ps1 -SessionId <id> [-ProfileId <id>]`。
10. 总结成功后，运行 `scripts/mark-session-summary.ps1 -SessionId <id> -ProfileId <id> -CursorAt <time>` 推进截止点。
11. 如果用户明确说“新建角色”或“角色工坊”，再运行 `scripts/ensure-role-archive-url.ps1 -ForceRestart` 返回本地前端入口。
12. 所有 PowerShell 脚本默认用 `powershell -ExecutionPolicy Bypass -File ...` 调用。

# 记忆与数据规则

- 每条记忆都必须写入 `eventAt`
- 手动记忆默认写到分钟；自动总结优先写到分钟，无法可靠定位时可退到小时
- `createdAt` 继续保留为写入本地档案的时间
- 角色数据保存在 `$HOME/.codex/role-archive-studio-data`
- 不要把本地角色与记忆数据打包进 skill 或上传仓库
- 默认记忆筛选逻辑应优先保留长期偏好、合作方式和重要已确认事实
- 不要把角色卡设定、一次性开发过程、临时测试细节默认写进长期记忆
- 记忆增量截止点按 `session + profile` 独立维护
- 角色运行摘要应保持短小，只保留角色身份、职责、语气和记忆重点

# 当前边界

- 聊天入口已支持按对话 session 绑定角色
- 前端页面当前主要用于创建、编辑和管理角色卡
- 前端本身不自动感知 Codex 窗口 ID
- 如果宿主未来能提供稳定会话 ID，可继续把前端 bootstrap 和激活流程完全切到 session 级

# 更新日志

## 2026-03-14

- 新增基于 `session` 的文字选角色流程
- 新增 `ensure-role-session.ps1`
- `list-role-profiles.ps1` greeting 阶段改为只读角色列表
- `activate-role.ps1`、`get-active-role.ps1`、`add-memory-item.ps1`、`update-memory-focus.ps1` 支持 `-SessionId`
- 新增 `get-session-summary-scope.ps1` 与 `mark-session-summary.ps1`
- 记忆增量截止点按 `session + profile` 独立维护
- 角色读取加入更短的 `runtimeSummary`
- PowerShell 脚本调用统一为 `powershell -ExecutionPolicy Bypass -File ...`
- 前端提示词预览区优化为短提示文案 + 限高滚动
- 前端记忆存档区恢复为按角色加载
