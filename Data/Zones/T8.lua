-- Zone Data: T8 (Ulduar)
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "T8"
tZonesData.tBlacklistKey = "tT8"
tZonesData.tZones = {
    ["Formation Grounds"] = {
        ["A"] = { sNPCID = "33113", sTarName = "Flame Leviathan", iIcon = 254102, tEnabledOptions = {"bFlameLeviathanFight","bFlameLeviathan"} },
    },
    ["The Colossal Forge"] = {
        ["A"] = { sNPCID = "33118", sTarName = "Ignis the Furnace Master", iIcon = 254092, tEnabledOptions = {"bIgnisFight","bIgnis"} },
    },
    ["Razorscale's Aerie"] = {
        ["A"] = { sNPCID = "33186", sTarName = "Razorscale", iIcon = 298670, tEnabledOptions = {"bRazorscaleFight","bRazorscale"} },
    },
    ["The Scrapyard"] = {
        ["A"] = { sNPCID = "33293", sTarName = "XT-002 Deconstructor", iIcon = 254104, tEnabledOptions = {"bXTFight","bXT"} },
        ["B"] = { sNPCID = "34004", sTarName = "Life Spark",            iIcon = 136050, tEnabledOptions = {"bXTFight","bLifeSpark"} },
        ["C"] = { sNPCID = "33344", sTarName = "XM-024 Pummeller",      iIcon = 132996, tEnabledOptions = {"bXTFight","bPummeller"} },
    },
    ["The Assembly of Iron"] = {
        ["A"] = { sNPCID = "32857", sTarName = "Stormcaller Brundir",  iIcon = 254108, tEnabledOptions = {"bIronCouncilFight","bStormcaller"} },
        ["B"] = { sNPCID = "32927", sTarName = "Runemaster Molgeim",   iIcon = 237375, tEnabledOptions = {"bIronCouncilFight","bRunemaster"} },
        ["C"] = { sNPCID = "32867", sTarName = "Steelbreaker",         iIcon = 254110, tEnabledOptions = {"bIronCouncilFight","bSteelbreaker"} },
    },
    ["The Celestial Planetarium"] = {
        ["A"] = { sNPCID = "32871", sTarName = "Algalon the Observer", iIcon = 254087, tEnabledOptions = {"bAlgalonFight","bAlgalon"} },
        bIsSingleBoss = true,
    },
    ["The Shattered Walkway"] = {
        ["A"] = { sNPCID = "32934", sTarName = "Right Arm", iIcon = 236314, tEnabledOptions = {"bKologarnFight","bRightArm"} },
        ["B"] = { sNPCID = "32930", sTarName = "Kologarn",  iIcon = 254095, tEnabledOptions = {"bKologarnFight","bKologarn"} },
        ["C"] = { sNPCID = "32933", sTarName = "Left Arm",  iIcon = 136101, tEnabledOptions = {"bKologarnFight","bLeftArm"} },
    },
    ["The Observation Ring"] = {
        ["A"] = { sNPCID = "33515", sTarName = "Auriaya",        iIcon = 254088, tEnabledOptions = {"bAuriayaFight","bAuriaya"} },
        ["B"] = { sNPCID = "34035", sTarName = "Feral Defender", iIcon = 132225, tEnabledOptions = {"bAuriayaFight","bFeralDefender"} },
    },
    ["The Halls of Winter"] = {
        ["A"] = { sNPCID = "32845", sTarName = "Hodir", iIcon = 254091, tEnabledOptions = {"bHodirFight","bHodir"} },
    },
    ["The Clash of Thunder"] = {
        ["A"] = { sNPCID = "32865", sTarName = "Thorim", iIcon = 298676, tEnabledOptions = {"bThorimFight","bThorim"} },
    },
    ["The Conservatory of Life"] = {
        ["A"] = { sNPCID = "32916", sTarName = "Snaplasher",           iIcon = 134196, tEnabledOptions = {"bFreyaFight","bSnaplasher"} },
        ["B"] = { sNPCID = "32919", sTarName = "Storm Lasher",         iIcon = 135990, tEnabledOptions = {"bFreyaFight","bStormLasher"} },
        ["C"] = { sNPCID = "33202", sTarName = "Ancient Water Spirit", iIcon = 135862, tEnabledOptions = {"bFreyaFight","bAncientWaterSpirit"} },
        ["D"] = { sNPCID = "32906", sTarName = "Freya",                iIcon = 254089, tEnabledOptions = {"bFreyaFight","bFreya"} },
    },
    ["The Spark of Imagination"] = {
        ["A"] = { sNPCID = "33670", sTarName = "Aerial Command Unit", iIcon = 254097, tEnabledOptions = {"bMimironFight","bMimironP3"} },
        ["B"] = { sNPCID = "33651", sTarName = "VX-001",              iIcon = 236221, tEnabledOptions = {"bMimironFight","bMimironP2"} },
        ["C"] = { sNPCID = "33432", sTarName = "Leviathan Mk II",     iIcon = 252186, tEnabledOptions = {"bMimironFight","bMimironP1"} },
        ["D"] = { sNPCID = "34057", sTarName = "Assault Bot",         iIcon = 132996, tEnabledOptions = {"bMimironFight","bAssaultBot"} },
    },
    ["The Descent into Madness"] = {
        ["A"] = { sNPCID = "33271", sTarName = "General Vezax",   iIcon = 254090, tEnabledOptions = {"bVezaxFight","bVezax"} },
        ["B"] = { sNPCID = "33524", sTarName = "Saronite Animus", iIcon = 135862, tEnabledOptions = {"bVezaxFight","bSaroniteAnimus"} },
    },
    ["The Prison of Yogg-Saron"] = {
        ["A"] = { sNPCID = "33288", sTarName = "Yogg-Saron",         iIcon = 254105, tEnabledOptions = {"bYoggSaronFight","bYoggSaron"} },
        ["B"] = { sNPCID = "33966", sTarName = "Crusher Tentacle",   iIcon = 133574, tEnabledOptions = {"bYoggSaronFight","bCrusherTentacle"} },
        ["C"] = { sNPCID = "33985", sTarName = "Corruptor Tentacle", iIcon = 237521, tEnabledOptions = {"bYoggSaronFight","bCorruptorTentacle"} },
    },
}

MBT:RegisterZonesSection(tZonesData)
