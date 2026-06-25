# RaidPreflight（进本检查清单）

进本前 / 开战前的 preflight 检查清单。像工业 HMI 的开机自检：进团队、进副本、开 boss 之前，自动核对你该带的消耗品、该有的增益、团队该有的职业构成，缺了一眼看出来。

> MoP Classic（泰坦怀旧时光，`## Interface: 50503`）/ zhCN。自包含，不依赖其他插件。

## 三个触发点

| 情境 | 触发事件 | 行为 |
|---|---|---|
| **术士拉人** | `CONFIRM_SUMMON` | 收起暴雪默认召唤弹窗，先弹检查清单。看完 **接受召唤**（`ConfirmSummon`）或 **取消**（`CancelSummon`） |
| **自己跑进本** | `PLAYER_ENTERING_WORLD` | 进入 5/10/25 人副本时弹一次。同一副本+难度在冷却期（默认 6h，近似一个副本周期）内不再弹 |
| **开战前** | `READY_CHECK`（团队倒计时/检查准备） | 针对**下一个 boss** 弹清单，可重新检查 |

## 开战即自动消失

preflight 是**开战前**的事。一旦进入战斗（`PLAYER_REGEN_DISABLED`），弹窗**立刻自己收起**——免得你忘了点、又被人意外开团，多一步确认手忙脚乱。本插件**绝不触碰任何开战逻辑**。

## 团队构成检查：职业 + 专精

法术易伤 / 精灵火这类「给 boss 的 debuff」，本插件**不在开战时检查**，而是**进本前/开战前**就把团队扫一遍，看「**有没有能提供它的职业、专精对不对**」：

- ✅ **专精可读**：自己 `GetSpecialization`，别人 `NotifyInspect → INSPECT_READY → GetInspectSpecialization`。`Inspect.lua` 组队后常驻预热缓存，ready check 时多半已就绪；没读到的回退职业级并标 **「专精待确认」(黄色 `!`)**。
- ❌ **单个天赋点不做**：MoP Classic 5.5 删了 WotLK 的 `GetTalentInfo(row,index)`，被检视单位的天赋点拿不到（MultiBossTracker 本身也放弃了天赋检测）。所以做到**专精**粒度——多数团队 debuff 来源按职业/专精已足够判断。

> 旁注：「debuff 真打上 boss 没有」是开战后的事，属于 MultiBossTracker 的范畴，本插件不碰。

## 检查项类型

模板里一条检查项是一个描述符：

```lua
{ sType = "aura_keyword", aKeywords = {"合剂"}, sLabel = "合剂 / 药剂" }  -- 身上有名字含关键字的 buff
{ sType = "item",  iItemID = 5512, iMin = 1, sLabel = "治疗石" }          -- 包里数量 >= iMin
{ sType = "comp",  aClasses = {"WARLOCK"}, sLabel = "法术易伤来源（术士）" } -- 团队有该职业
{ sType = "comp",  aClasses = {"WARLOCK"}, aSpecIDs = {266}, sLabel = "毁灭术士" } -- 职业 + 专精
```

## 模板三级覆盖

通用 → 副本（按 `instanceMapID`）→ boss（按 `encounterID`），逐级追加。内置一套合理默认；用户覆盖写在 `RaidPreflightDB.tZones`：

```lua
-- 按「中文区域名」索引，encID 与 MBT 数据对齐
RaidPreflightDB.tZones["熔火之心"] = {
  tItems = { { sType="item", iItemID=12345, sLabel="本本专用药" } },
  tComp  = { { sType="comp", aClasses={"PRIEST"}, sLabel="心灵之火" } },
  tBosses = {
    [665] = { tAuras = { { sType="aura_keyword", aKeywords={"防火"}, sLabel="防火合剂" } } },
  },
}
```

## 配置面板 / 编辑器 / 分享

全部走暴雪原生 UI（无 Ace 依赖）：

- **设置面板**（`/rpf` 或 Esc → 界面 → 插件 → RaidPreflight）：总开关、三个触发器、进本冷却滑条、重置记录，以及打开编辑器/导入/导出的按钮。
- **检查清单编辑器**（`/rpf edit`）：先选**作用域**（通用 / 某副本 / 某副本的某 boss），看该作用域的自定义检查并增删。新增时选类型（物品 / 光环关键字 / 团队职业±专精）+ 标签 + 参数。
  - 物品：填 itemID（如 `5512`）
  - 光环关键字：逗号分隔（如 `合剂,营养充足`）
  - 团队职业：职业 token + 可选专精 ID（如 `WARLOCK 266 267`，数字视为专精）
- **导出 / 导入**（`/rpf export` / `/rpf import`）：把你的触发开关 + 自定义清单序列化成 `RPF1!` 开头的分享串，发给朋友粘贴导入。

## 斜杠命令

```
/rpf            打开设置面板
/rpf check      手动检查当前情境
/rpf edit       编辑检查清单
/rpf export     导出分享串
/rpf import     导入分享串
/rpf reset      清空进本弹窗记录（重新弹）
/rpf on|off     总开关
/rpf summon|enter|pull   切换对应触发器
```

## Boss 顺序：复用 MultiBossTracker，不维护两份

开战前「下一个 boss」的推断**直接复用 MBT 的数据**：

- **首选**：运行时读 `_G.MultiBossTracker.localizedZones`（MBT 已本地化成中文的副本/顺序表）。装了 MBT 就零拷贝拿到**全部**副本，随 MBT 更新自动同步。`## OptionalDeps: MultiBossTracker` 保证它先加载。
- **回退**：没装 MBT 时用 `Data/Zones.lua` 里的同构小种子（仅熔火之心示例）。

推断逻辑也照搬 MBT：子区域优先 > 主区域 → 当前 encounter（`iStartingFight` 起，`ENCOUNTER_END` 顺 `iNextEncounter` 推进）→ 鼠标悬浮/选中某 boss 的 NPCID 直接覆盖（玩家表态优先）。

## ⚠️ 种子数据

`Data/Consumables.lua`（itemID）是**示例种子**——泰坦怀旧时光对掉落多有改动，请按服务器校对。光环检查尽量用「名字关键字」匹配，跨 itemID 改动更稳。Boss 顺序见上，复用 MBT 无需在此维护。

## 路线图

- v2：AceConfig 配置面板（可视化编辑模板）+ 导入导出分享串
- 后续：inspect 读专精做精确团队构成；DBM/BigWigs 拉条触发；开战后 debuff 落地验证（与 MultiBossTracker 联动）
