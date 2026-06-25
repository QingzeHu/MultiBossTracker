# RaidPreflight（进本检查清单）

进本前 / 开战前的 preflight 检查清单。像工业 HMI 的开机自检：进团队、进副本、开 boss 之前，自动核对你该带的消耗品、该有的增益、团队该有的职业构成，缺了一眼看出来。

> MoP Classic（泰坦怀旧时光，`## Interface: 50503`）/ zhCN。自包含，不依赖其他插件。

## 三个触发点

| 情境 | 触发事件 | 行为 |
|---|---|---|
| **术士拉人** | `CONFIRM_SUMMON` | 收起暴雪默认召唤弹窗，先弹检查清单。看完 **接受召唤**（`ConfirmSummon`）或 **取消**（`CancelSummon`） |
| **自己跑进本** | `PLAYER_ENTERING_WORLD` | 进入 5/10/25 人副本时弹一次。同一副本+难度在冷却期（默认 6h，近似一个副本周期）内不再弹 |
| **开战前** | `READY_CHECK`（团队倒计时/检查准备） | 针对**下一个 boss** 弹清单，可重新检查 |

## 一个重要前提

能不能「进本前」查，取决于这东西在引擎里是什么：

- ✅ **自身物资**（包里物品，`GetItemCount`）、**自身增益**（`UnitAura`，合剂/食物 buff）——随时可查。
- ✅ **团队职业构成**——扫 `raid/party` 的职业，判断「提供某 debuff 的职业在不在场」。
- ❌ **打在 boss 身上的 debuff**（法术易伤 / 破甲等）——开战前 boss 身上根本没有，查不了。开战前只能查「**有没有能上它的职业**」；「**真打上没有**」要开战后验证（那是 MultiBossTracker 的活）。

> v1 团队检查只能按**职业**判断，读不到天赋/专精（inspect 留待后续）。

## 检查项类型

模板里一条检查项是一个描述符：

```lua
{ sType = "aura_keyword", aKeywords = {"合剂"}, sLabel = "合剂 / 药剂" }  -- 身上有名字含关键字的 buff
{ sType = "item",  iItemID = 5512, iMin = 1, sLabel = "治疗石" }          -- 包里数量 >= iMin
{ sType = "comp",  aClasses = {"WARLOCK"}, sLabel = "法术易伤来源（术士）" } -- 团队有该职业
```

## 模板三级覆盖

通用 → 副本（按 `instanceMapID`）→ boss（按 `encounterID`），逐级追加。内置一套合理默认；用户覆盖写在 `RaidPreflightDB.tZones`：

```lua
RaidPreflightDB.tZones[409] = {
  tItems = { { sType="item", iItemID=12345, sLabel="本本专用药" } },
  tComp  = { { sType="comp", aClasses={"PRIEST"}, sLabel="心灵之火" } },
  tBosses = {
    [663] = { tAuras = { { sType="aura_keyword", aKeywords={"防火"}, sLabel="防火合剂" } } },
  },
}
```

## 斜杠命令

```
/rpf            手动检查当前情境
/rpf reset      清空进本弹窗记录（重新弹）
/rpf on|off     总开关
/rpf summon|enter|pull   切换对应触发器
```

## ⚠️ 种子数据

`Data/Consumables.lua`（itemID）和 `Data/Zones.lua`（boss 顺序）是**示例种子**——泰坦怀旧时光对掉落/副本多有改动，请按服务器实际校对补全。光环检查尽量用「名字关键字」匹配，跨 itemID 改动更稳。

## 路线图

- v2：AceConfig 配置面板（可视化编辑模板）+ 导入导出分享串
- 后续：inspect 读专精做精确团队构成；DBM/BigWigs 拉条触发；开战后 debuff 落地验证（与 MultiBossTracker 联动）
