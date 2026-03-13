# 角色存档工坊

本 skill 提供一个本地角色档案与记忆管理界面，用于创建角色、切换当前角色、保存私有记忆，并把角色存档留在本地。

## 特点
- 角色卡与记忆分离管理
- 角色存档只保存在本地，不随 skill 分发
- 支持记忆重点确认
- 每条记忆包含事件时间 `eventAt`
- 手动新增记忆自动写入当前本地时间到分钟

## 本地数据目录
- `$HOME/.codex/role-archive-studio-data`

## 启动界面
```powershell
powershell -ExecutionPolicy Bypass -File "$HOME/.codex/skills/role-archive-studio/scripts/ensure-role-archive-url.ps1" -ForceRestart -Port 48678
```
