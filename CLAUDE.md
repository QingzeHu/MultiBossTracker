# MultiBossTracker — 开发须知

WoW 插件：一屏显示最多 10 个 boss 的血条 / DoT / 施法条，支持点击施法。

## 客户端

- **MoP Classic（泰坦怀旧服）**，`## Interface: 50503`（5.5.x 系）。
- **zhCN 客户端**：单位名按中文匹配。

## FrameXML 参考源（查 API / 暴雪默认实现）

很多「像 API」的全局函数其实是 FrameXML 里的普通 Lua（源码可读），不是引擎 C 函数。判断函数真实行为、或参考暴雪自己怎么做某个 UI 之前，**先查 FrameXML 源码，别凭记忆猜**。

- 本机已 clone（仓库外，浅克隆 ~14M）：`/home/qingze/reference/WoW_UI_Source_MoP`（版本 5.4.8，祖传工具函数与 5.5.x 一致）
- 在线浏览：https://www.townlong-yak.com/framexml/
- 更广版本覆盖：https://github.com/tomrus88/BlizzardInterfaceCode
- 用法：直接 `grep -rn "function 名字" /home/qingze/reference/WoW_UI_Source_MoP/`

## 核心机制（改动前必知）

- **点击切目标**靠 `/targetexact <本地化名>`（精确匹配）→ 名字必须跟客户端**完全一致**。
- **DoT / 血量**靠 **NPCID**（战斗日志）匹配，与名字无关。
- 推论：**「DoT 正常但点击切不了目标」≈ 译名对不上客户端**，先查 `Locale/zhCN.lua`。
- 译名管线：`sTarName`(英文) → `LocalizeTable` / `L()`（`Locale/Locale.lua`）→ 喂给点击宏。

## 流程

- **每次改完同步到游戏**：`rsync -a --delete --exclude=.git --exclude=.claude <项目>/ "/mnt/c/Program Files (x86)/World of Warcraft/_classic_titan_/Interface/AddOns/MultiBossTracker/"`，然后游戏内 `/reload`。
- **发版**：bump `MultiBossTracker.toc` 的 `## Version`，在 `CHANGELOG.md` 顶部加 `## x.y.z — 日期` 段，commit，打 `vx.y.z` tag 并 push → GitHub Actions 自动打包发 release（`.github/workflows/release.yml`，已 `--exclude assets` 等，发布包不含截图/文档）。
- **导入导出兼容**：改动若涉及配置，评估对 `MBT1!` profile 字符串格式的影响，只有真正破坏时才升前缀。
