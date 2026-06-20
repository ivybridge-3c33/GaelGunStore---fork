GGS_HistoricModeBlacklist = GGS_HistoricModeBlacklist or {}

local M = GGS_HistoricModeBlacklist

local function sandboxBool(section, key, defaultValue)
    local root = SandboxVars
    local value = root and root[section] and root[section][key] or nil
    if value == nil then
        return defaultValue
    end

    local valueType = type(value)
    if valueType == "boolean" then
        return value
    end
    if valueType == "number" then
        return value ~= 0
    end
    if valueType == "string" then
        local lower = value:lower()
        return lower == "true" or lower == "1" or lower == "yes" or lower == "on"
    end

    return defaultValue
end

function M.isEnabled()
    return sandboxBool("GGSGS", "Pre1994LootOnly", false)
end

-- Items known or assumed to be post-1993. Keep this table explicit so the
-- historical mode can be adjusted by ID without touching loot generation code.
M.Items = {
    ["Base.GM94"] = true,
    ["Base.RG6"] = true,

    ["Base.AA12"] = true,
    ["Base.BenelliM4"] = true,
    ["Base.Beretta_A400"] = true,
    ["Base.Beretta_A400_Short"] = true,
    ["Base.DVB15"] = true,
    ["Base.KSG"] = true,
    ["Base.QBA"] = true,
    ["Base.QBS09"] = true,
    ["Base.QBS09_Short"] = true,
    ["Base.Saiga12"] = true,
    ["Base.SWMP_12"] = true,
    ["Base.VR80"] = true,

    ["Base.Beretta_PX4"] = true,
    ["Base.CircuitJudgeRifle"] = true,
    ["Base.DeagleCar14"] = true,
    ["Base.FiveSeven"] = true,
    ["Base.FN502_22LR"] = true,
    ["Base.FNX45"] = true,
    ["Base.G2"] = true,
    ["Base.Glock43"] = true,
    ["Base.Glock_tactical"] = true,
    ["Base.GSH18"] = true,
    ["Base.HKMK23"] = true,
    ["Base.MP_R8"] = true,
    ["Base.OTS_33"] = true,
    ["Base.P220_Elite"] = true,
    ["Base.P99"] = true,
    ["Base.Rhino20DS"] = true,
    ["Base.RSH12"] = true,
    ["Base.RugerLC"] = true,
    ["Base.SR1M"] = true,
    ["Base.SW500"] = true,
    ["Base.SWM327"] = true,
    ["Base.SWM629_Deluxe"] = true,
    ["Base.SWM1854"] = true,
    ["Base.Taurus_raging_bull"] = true,
    ["Base.Taurus_raging_bull460"] = true,
    ["Base.Taurus_RT85"] = true,
    ["Base.USP45"] = true,
    ["Base.VictorySW22"] = true,
    ["Base.XD"] = true,

    ["Base.AEK919"] = true,
    ["Base.APC9K"] = true,
    ["Base.CBJ"] = true,
    ["Base.CZScorpion"] = true,
    ["Base.K7"] = true,
    ["Base.KAC_PDW"] = true,
    ["Base.Kriss9mm"] = true,
    ["Base.KrissVector45"] = true,
    ["Base.MP7"] = true,
    ["Base.MP9"] = true,
    ["Base.MPX"] = true,
    ["Base.MSST"] = true,
    ["Base.MX4"] = true,
    ["Base.P99_Kilin"] = true,
    ["Base.PP_Bizon"] = true,
    ["Base.PP2000"] = true,
    ["Base.Saiga9mm"] = true,
    ["Base.UMP45"] = true,
    ["Base.UMP45_long"] = true,
    ["Base.Veresk"] = true,

    ["Base.ACE21"] = true,
    ["Base.ACE23"] = true,
    ["Base.ACE52_CQB"] = true,
    ["Base.ACE53"] = true,
    ["Base.ACR"] = true,
    ["Base.ADS"] = true,
    ["Base.AEK"] = true,
    ["Base.AK101"] = true,
    ["Base.AK103"] = true,
    ["Base.AK12"] = true,
    ["Base.AK19"] = true,
    ["Base.AK5C"] = true,
    ["Base.AK9"] = true,
    ["Base.AKU12"] = true,
    ["Base.AK_minidrako"] = true,
    ["Base.AN94"] = true,
    ["Base.AR160"] = true,
    ["Base.ASH_12"] = true,
    ["Base.CZ805"] = true,
    ["Base.DDM4"] = true,
    ["Base.FN2000"] = true,
    ["Base.G36C"] = true,
    ["Base.G27"] = true,
    ["Base.Groza"] = true,
    ["Base.HK416"] = true,
    ["Base.HKG28"] = true,
    ["Base.HoneyBadger"] = true,
    ["Base.IA2"] = true,
    ["Base.IA2_308"] = true,
    ["Base.LR300"] = true,
    ["Base.LVOA"] = true,
    ["Base.M4"] = true,
    ["Base.M110"] = true,
    ["Base.M82A3"] = true,
    ["Base.MK18"] = true,
    ["Base.MTAR"] = true,
    ["Base.QBZ951"] = true,
    ["Base.R5"] = true,
    ["Base.SAR21"] = true,
    ["Base.ScarH"] = true,
    ["Base.ScarL"] = true,
    ["Base.SIG_553"] = true,
    ["Base.SIG516"] = true,
    ["Base.SR3M"] = true,
    ["Base.SR47"] = true,
    ["Base.SR338"] = true,
    ["Base.SS2V5"] = true,
    ["Base.SVD12"] = true,
    ["Base.SVDK"] = true,
    ["Base.SVDK_short"] = true,
    ["Base.VSS_Tactical"] = true,
    ["Base.VEPR"] = true,
    ["Base.XM8"] = true,

    ["Base.HK_121"] = true,
    ["Base.LSAT"] = true,
    ["Base.M240B"] = true,
    ["Base.M60E4"] = true,
    ["Base.MG4"] = true,
    ["Base.Negev"] = true,
    ["Base.PKP"] = true,
    ["Base.QBB95"] = true,
    ["Base.RPK12"] = true,
    ["Base.RPK16"] = true,
    ["Base.Type88"] = true,

    ["Base.CS5"] = true,
    ["Base.JNG90"] = true,
    ["Base.L115A"] = true,
    ["Base.M98B"] = true,
    ["Base.M200"] = true,
    ["Base.Scout_elite"] = true,
    ["Base.SV98"] = true,
    ["Base.VSSK"] = true,

    ["Base.M320_GL"] = true,
    ["Base.M320_GL_empty"] = true,
    ["Base.Scar_GL"] = true,
    ["Base.Scar_GL_empty"] = true,

    ["Base.Accupoint"] = true,
    ["Base.Acog_ecos"] = true,
    ["Base.Acog_TA648"] = true,
    ["Base.ANPEQ_10"] = true,
    ["Base.ANPEQ_2"] = true,
    ["Base.ATN_Thor"] = true,
    ["Base.BaldrPro"] = true,
    ["Base.Bravo4"] = true,
    ["Base.Comp_M4"] = true,
    ["Base.Compact4x"] = true,
    ["Base.Coyote"] = true,
    ["Base.CP1"] = true,
    ["Base.CrimsonRedDot"] = true,
    ["Base.DBAL_A2"] = true,
    ["Base.Dbal9021"] = true,
    ["Base.Deltapoint"] = true,
    ["Base.Eotech"] = true,
    ["Base.Eotech_vudu"] = true,
    ["Base.Eotech_XPS3"] = true,
    ["Base.HAMR"] = true,
    ["Base.InsightLA5"] = true,
    ["Base.InsightWMX200"] = true,
    ["Base.IRNV"] = true,
    ["Base.Leapers_UTG3"] = true,
    ["Base.M600P"] = true,
    ["Base.M962LT"] = true,
    ["Base.MicroT1"] = true,
    ["Base.MiniRedDot"] = true,
    ["Base.Ncstar_laser"] = true,
    ["Base.OKP7"] = true,
    ["Base.PEQ15"] = true,
    ["Base.PM_IILP"] = true,
    ["Base.RDS"] = true,
    ["Base.Romeo3"] = true,
    ["Base.RX01"] = true,
    ["Base.SigSauerRomeo3"] = true,
    ["Base.SLDG"] = true,
    ["Base.Spectre"] = true,
    ["Base.Springfield_longrange_scope"] = true,
    ["Base.SteinerTac2"] = true,
    ["Base.Surefire_light"] = true,
    ["Base.Surefire_M925"] = true,
    ["Base.SurefireX400"] = true,
    ["Base.TritiumSights"] = true,
    ["Base.TruBrite"] = true,
    ["Base.VenomRDS"] = true,
    ["Base.VortexRedDot"] = true,
    ["Base.ZaMiniRDS"] = true,
    ["Base.Zenit2P"] = true,

    ["Base.AngleGrip"] = true,
    ["Base.bcm"] = true,
    ["Base.cobra_tactical"] = true,
    ["Base.Dtkp_Hexagon_Silencer"] = true,
    ["Base.Dtkp_Silencer"] = true,
    ["Base.fortis_shift"] = true,
    ["Base.GripPod"] = true,
    ["Base.hera_arms"] = true,
    ["Base.Hexagon_12G_Suppressor"] = true,
    ["Base.kac_vertical_grip"] = true,
    ["Base.keymod_sig"] = true,
    ["Base.keymod_sig_vertical"] = true,
    ["Base.keymod_vertical"] = true,
    ["Base.Kriss9mm_Silencer"] = true,
    ["Base.m_lok_magpul"] = true,
    ["Base.magpul_afg"] = true,
    ["Base.magpul_rvg"] = true,
    ["Base.Osprey_Silencer"] = true,
    ["Base.PotatoGrip"] = true,
    ["Base.rtm_pillau"] = true,
    ["Base.Saiga9_Silencer"] = true,
    ["Base.Salvo_12G_Suppressor"] = true,
    ["Base.Suppx_Silencer"] = true,
    ["Base.tango_down"] = true,
    ["Base.TGP_Silencer"] = true,
    ["Base.vtac_uvg"] = true,
    ["Base.zenit_b25u"] = true,
    ["Base.zenit_rk_1"] = true,
    ["Base.zenit_rk_5"] = true,
    ["Base.zenit_rk6"] = true,

    ["Base.ak_hg_545_design"] = true,
    ["Base.ak_hg_cnc"] = true,
    ["Base.ak_hg_hexagon"] = true,
    ["Base.ak_hg_krebs"] = true,
    ["Base.ak_hg_magpul_moe"] = true,
    ["Base.ak_hg_magpul_zhukov"] = true,
    ["Base.ak_hg_vltor"] = true,
    ["Base.AKHGtactical"] = true,
    ["Base.AK12_stock"] = true,
    ["Base.AK19_stock"] = true,
    ["Base.AK9_stock"] = true,
    ["Base.AN94_stock"] = true,
    ["Base.ak_mount_sag"] = true,
    ["Base.ak_mount_xd_rgl"] = true,
    ["Base.ak_stock_archangel"] = true,
    ["Base.ak_stock_fab"] = true,
    ["Base.ak_stock_hera"] = true,
    ["Base.ak_stock_hexagon"] = true,
    ["Base.ak_stock_zenit_magpul"] = true,
    ["Base.ak_stock_zenit_pt_1"] = true,
    ["Base.ak_stock_zenit_pt_3"] = true,
    ["Base.ak_stock_zenit_pt-1"] = true,
    ["Base.ak_stock_zenit_pt-3"] = true,
    ["Base.M1014_stock"] = true,
    ["Base.R870_magpul_stock"] = true,
    ["Base.R870_sps_stock"] = true,
    ["Base.R870_Tactical_Grip"] = true,
    ["Base.R870_Tactical_Grip_short"] = true,
    ["Base.Scar_pdw_stock"] = true,
    ["Base.Scar_ssr_stock"] = true,
    ["Base.Scar_stock"] = true,
    ["Base.stock_pistol_fab"] = true,
    ["Base.svd_handguard_xrs_drg"] = true,
    ["Base.VSS_stock_Tactical"] = true,
    ["Base.win_archangel_handguard"] = true,
    ["Base.win_archangel_stock"] = true,
}

M.Prefixes = {
    "Base.ar10_hg_",
    "Base.ar15_",
    "Base.Scar_",
}

local function normalizeFullType(fullType)
    if type(fullType) ~= "string" then
        return nil
    end
    if fullType:find("%.") then
        return fullType
    end
    return "Base." .. fullType
end

function M.isBlacklisted(fullType)
    fullType = normalizeFullType(fullType)
    if not fullType then
        return false
    end
    if M.Items[fullType] then
        return true
    end
    for _, prefix in ipairs(M.Prefixes) do
        if fullType:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

function M.shouldBlock(fullType)
    return M.isEnabled() and M.isBlacklisted(fullType)
end

return M
