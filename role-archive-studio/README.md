# 角色存档工坊

本 skill 用于在本地创建、选择、激活和维护角色卡与私有记忆档案。它适合想在 Codex 不同对话里延续不同角色设定、又希望角色数据只保存在本地的人。

## 核心功能

- 本地角色卡管理：创建、编辑、删除、激活角色
- 私有记忆存档：角色记忆只留在本地，不随 skill 分发
- 文字选角流程：新对话先发“你好”时，可先看文字角色列表再绑定角色
- 前端角色工坊：需要时可打开本地网页进行创建、选择和管理
- 会话级角色绑定：不同对话可绑定不同角色
- 增量记忆总结：只总结某个对话里该角色上次截止点之后的新内容
- 记忆时间戳：每条记忆都带 `eventAt`
- 记忆重点确认：首次写记忆前可先确认这个角色以后更该记住什么

## 推荐用法

### 新对话里先文字选角色

1. 先发“你好”
2. 返回本地角色列表
3. 直接回复角色名、编号或 ID
4. 角色绑定到当前对话后继续协作

你也可以直接发：

- `新建角色`
- `角色工坊`

来打开本地前端界面。

### 打开本地前端界面

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/ensure-role-archive-url.ps1" -ForceRestart -Port 48678
```

默认入口：

`http://127.0.0.1:48678/`

## 常用脚本

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/list-role-profiles.ps1" -AsJson
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/ensure-role-session.ps1" -AsJson
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/activate-role.ps1" -SessionId "session-abc" -Name "卖蘑菇的乌龟" -AsJson
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/get-active-role.ps1" -SessionId "session-abc" -AsJson
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/get-session-summary-scope.ps1" -SessionId "session-abc" -AsJson
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/mark-session-summary.ps1" -SessionId "session-abc" -ProfileId "role-id" -CursorAt "2026-03-14T21:45:00"
```

## 数据规则

- 本地数据目录：`$HOME/.codex/role-archive-studio-data`
- 角色数据与记忆数据不应打包进 skill 或上传到仓库
- 手动新增记忆时，`eventAt` 默认写到分钟
- 自动总结记忆时，优先写到分钟；无法可靠定位时可退到小时
- 增量总结截止点按 `session + profile` 独立维护

## 前端说明

- 角色编辑页右侧提供提示词预览
- 预览标题下只显示短提示文案，不再重复整段功能简介
- 预览框有限高和滚动，避免长提示词把整个页面撑得过长
- 记忆存档按当前角色加载，不会把别的角色记忆一起塞进首屏

## 更新日志

### 2026-03-14

- 新增基于 `session` 的文字选角色流程，支持“你好 -> 文字列角色 -> 文字绑定角色”
- 新增 `ensure-role-session.ps1`
- `list-role-profiles.ps1` 改为 greeting 阶段只读角色列表，不再先创建 session
- `activate-role.ps1`、`get-active-role.ps1`、`add-memory-item.ps1`、`update-memory-focus.ps1` 等脚本支持 `-SessionId`
- 新增 `get-session-summary-scope.ps1` 与 `mark-session-summary.ps1`
- 记忆增量截止点改为按 `session + profile` 独立维护
- 角色读取加入更短的 `runtimeSummary`，用更小上下文成本增强角色区分感
- PowerShell 调用统一为 `powershell -ExecutionPolicy Bypass -File ...`
- 前端提示词预览区优化：不再重复显示整段功能简介，预览框改为限高滚动
- 前端记忆存档区恢复为按角色加载，避免因旧底板回滚导致列表不显示
