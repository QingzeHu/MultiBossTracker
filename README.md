# 多目标 Boss 追踪 (MultiBossTracker)

一屏同时显示最多 5 个 boss 的状态，支持隔空点击施法。专为多 dot / 多目标战斗设计的 WoW 插件，运行在 MoP Classic 5.5（中国官服 / 泰坦怀旧时光）。

## 功能

- 进入副本/主城自动识别区域，最多显示 5 个 boss 框体（A/B/C/D/E）
- 每个框体显示：boss 实时 3D 模型 (可切换 2D 头像)、HP 条、施法条、你自己的 DoT 图标行
- **点击框体即可对那只 boss 释放任意技能而不切走当前目标**（左键 / 右键 / 中键 / 侧键 4 / 侧键 5 + Shift / Ctrl / Alt 修饰，每职业 20 个绑定槽）
- DoT 倒计时显示真实剩余时间（直接读 `UnitDebuff`）
- 当前 target 的框体高亮（HP 变亮 + 左侧金色竖条）
- 紧凑 / 完整两种外观可选
- 框体可拖拽，多配置档独立保存

## 目录结构

```
MultiBossTracker/
├── MultiBossTracker.toc      # 插件清单
├── Core.lua                  # 入口 + AceDB + 事件总线
├── ClickCast.lua             # SecureActionButton 宏生成
├── Locale/                   # 中文本地化
├── Data/
│   ├── Classes/              # 各职业 DoT / 伤害咒语数据
│   └── Zones/                # 各副本 boss NPCID 数据库 (T1-T10)
├── Dispatchers/              # 事件派发层
│   ├── ZoneDispatcher.lua    # 区域 / 遭遇战切换
│   ├── DotDispatcher.lua     # CLEU → DoT 路由
│   ├── CastDispatcher.lua    # NPC 施法监听
│   └── HealthUpdater.lua     # raid 扫描取血量
├── Frames/                   # 框体 UI
├── Options/                  # 设置面板 (AceConfig)
└── Libs/                     # Ace3 依赖
```

## 斜杠命令

```
/mbt                  打开设置面板
/mbt where            显示当前区域和目标的 NPCID（用于排查）
/mbt showmacro [A-E]  打印某个框体的点击施法宏
/mbt lock             锁定框体位置
/mbt unlock           解锁拖动
/mbt reset            复位到屏幕中央
```

## 技术备注

- **客户端适配**：MoP Classic 5.5（TOC 50503）。安全按钮使用 `SecureActionButtonTemplate` + `BackdropTemplate`。
- **DoT 时长精度**：CLEU 触发时优先 `UnitDebuff` 读取真实 duration / expirationTime；找不到 unit token 时回退用 `UnitSpellHaste` 计算估算时长。
- **本地化**：内部数据用英文 key，运行时翻译为中文匹配 `GetSubZoneText()` 返回值。
- **事件总线**：自实现的 `MBT:FireEvent` / `MBT:RegisterMDFEvent` pub/sub。
