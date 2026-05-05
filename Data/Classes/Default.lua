-- Class Data: Default (catch-all for classes without bespoke data)
local addonName, MBT = ...

local tAuraData = {}
tAuraData.tDotAuras       = {}
tAuraData.tDamageTriggers = {}
tAuraData.tDamageInfos    = {}
tAuraData.tSpellsInfos    = {}
tAuraData.tDotOrderIndices = {}
tAuraData.fExecuteRange   = 0
tAuraData.tBlacklist      = {}
-- bindings get filled at format-time using the player's class

MBT:RegisterClassData("DEFAULT", tAuraData)
