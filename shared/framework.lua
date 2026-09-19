-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · shared/framework.lua
-- Which framework are we running on? One answer, read by server and client alike.
--
-- ★ Why a layer here when w_lib already ships a full bridge?
--
--   w_lib's bridge unifies what is *read* -- cash, gold, character identifier,
--   job -- and we already build on it: server/Commands.lua and server/metabolism.lua
--   know no framework at all.
--
--   But the HUD needs what no bridge unifies: **events**. They are fired under
--   different names, and some have no counterpart whatsoever -- VORP has tokens
--   and XP, RSG has bloodmoney and banks.
--
--   So this file does not duplicate w_lib. It answers one question -- which
--   framework? -- and then client/framework.lua and server/framework.lua wire
--   up the events of each.
--
-- ⚠️ QBR is treated as RSG, not because it is RSG, but because the two share one
--   PlayerData contract (citizenid · money · metadata) -- and that is everything
--   the HUD reads. Should the contract ever diverge, split it here, not at the
--   call sites.
-- ════════════════════════════════════════════════════════════════════════════

WFw = WFw or {}

local cached = nil

--- Framework name as w_lib sees it: 'vorp' · 'rsgcore' · 'qbr' · nil if not detected yet.
---@return string|nil
function WFw.name()
    if cached then return cached end

    local ok, name = pcall(function() return exports.w_lib:FwName() end)

    if ok and type(name) == 'string' and name ~= '' then
        cached = name
        return cached
    end

    -- ★ Fall back to resource state rather than the bridge: on server boot w_hud
    --   can start before w_lib finishes detecting (detection is a retry loop).
    --   Without this the first call reads nil, caches it, and the HUD stays
    --   framework-less forever.
    --
    --   This branch is deliberately NOT cached: it is a guess until the bridge
    --   answers for itself.
    if GetResourceState('vorp_core') == 'started' then return 'vorp' end
    if GetResourceState('rsg-core') == 'started' then return 'rsgcore' end
    if GetResourceState('qbr-core') == 'started' then return 'qbr' end

    return nil
end

---@return boolean
function WFw.isVorp()
    return WFw.name() == 'vorp'
end

--- RSG and QBR together -- one PlayerData contract (see the warning above).
---@return boolean
function WFw.isRSG()
    local n = WFw.name()
    return n == 'rsgcore' or n == 'qbr'
end

--- Has detection settled? (the bridge's answer, not the resource-state guess)
---@return boolean
function WFw.ready()
    local ok, ready = pcall(function() return exports.w_lib:FwReady() end)
    return ok and ready == true
end

--- The framework core -- RSGCore or the VORP core. Called on demand, never cached:
--- the RSG core object is replaced on `RSGCore:Client:UpdateObject`.
---@return table|nil
function WFw.core()
    local ok, core = pcall(function() return exports.w_lib:FwGetCore() end)
    return ok and core or nil
end
