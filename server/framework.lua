-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · server/framework.lua
-- Mirroring needs into the framework -- what RSG needs and what VORP does not
--
-- ═══ Why VORP needs nothing here and RSG does ═══
--
--   In VORP, hunger and thirst were never in the core at all -- they lived in a
--   separate resource, vorp_metabolism, and we replaced it (server/metabolism.lua
--   warns against running both). Scripts that query it query it through its events,
--   and we answer those in client/needs.lua. So there is no third place to mirror
--   the value into.
--
--   In RSG, hunger and thirst are **inside the core**: PlayerData.metadata.hunger
--   and .thirst. And everything reads from there -- rsg-hud, food scripts, medical,
--   jobs. So if we owned the value and never wrote it back, half the server would
--   see a permanently well-fed player while they starve on our side.
--
--   The mirroring is therefore one-way: we are the owner, the metadata is a mirror.
--
-- ⚠️ This has an explicit limit, stated so it is not discovered by experiment: an
--   RSG script writing straight into the metadata (SetMetaData) is invisible to us
--   -- no native intercepts the write. So whoever wants to drain hunger from their
--   own script should use our interface:
--
--       exports.w_hud:AddNeed(src, 'hunger', -20)
--       exports.w_hud:SetNeed(src, 'thirst', 50)
--       TriggerEvent('w_hud:server:setNeed', src, 'hunger', 50)
--
--   Otherwise the metadata is read exactly once: on the first load of a character
--   that has no row with us (the seed below) -- so their old value carries over
--   instead of being wiped with a hundred.
-- ════════════════════════════════════════════════════════════════════════════

WFwSrv = WFwSrv or {}

--- RSG and QBR together -- one PlayerData contract (citizenid · money · metadata), as
--- the library sees it (w.framework:is compares with the bridge's detection).
---@return boolean
local function frameworkIsRSG()
    return w.framework:is('rsg') or w.framework:is('qbr')
end

--- The RSG player object. Read on every call, never cached: the core is replaced
--- when rsg-core restarts, and a stored object becomes an empty shell.
---
--- ★ Through exports.w_lib:FwGetUser, not FwGetCore + Functions.GetPlayer: on the RSG
---   family the bridge answers with exactly Core.Functions.GetPlayer(src), and asking for
---   the player alone keeps the whole core object (Shared.Items, Jobs, every function)
---   from being copied across the export boundary on every mirror tick. The player still
---   arrives as a data copy whose functions are callable references -- the same shape
---   the seed and the mirror below already handle.
---@param src number
---@return table|nil
local function rsgPlayer(src)
    if not frameworkIsRSG() then return nil end

    local ok, player = pcall(function() return exports.w_lib:FwGetUser(src) end)
    return (ok and type(player) == 'table') and player or nil
end

-- ════════════════════════════════════════════════════════════════════════════
-- The seed -- an old value that must not be wiped
-- ════════════════════════════════════════════════════════════════════════════

--- Starting values for a character with no row in w_hud_needs.
---
--- ★ Without this, every player on a running RSG server logs in at hunger 100 and
---   thirst 100 the day the HUD is installed -- wiping the whole server's state in
---   one stroke. It is the first thing players notice and the last thing anyone
---   guesses the cause of.
---@param src number
---@return table|nil { hunger = number, thirst = number }
function WFwSrv.seed(src)
    local player = rsgPlayer(src)
    if not player then return nil end

    local md = player.PlayerData and player.PlayerData.metadata
    if type(md) ~= 'table' then return nil end

    local hunger, thirst = tonumber(md.hunger), tonumber(md.thirst)
    if not hunger and not thirst then return nil end

    return { hunger = hunger, thirst = thirst }
end

-- ════════════════════════════════════════════════════════════════════════════
-- The mirror -- our value into the metadata
-- ════════════════════════════════════════════════════════════════════════════

--- ★ A per-player time throttle: decay broadcasts every few seconds, and SetMetaData
---   in RSG fires RSGCore:Player:SetPlayerData down to the client. So writing without
---   a throttle means a network broadcast per player per point of hunger.
---
---   Five seconds is plenty: nothing in RSG reads hunger at a finer resolution.
local MIRROR_EVERY = 5000
local lastMirror = {}

---@param src number
---@param needs table { hunger, thirst }
---@param force boolean|nil bypass the throttle (on save and on disconnect)
function WFwSrv.mirror(src, needs, force)
    if type(needs) ~= 'table' then return end

    local now = GetGameTimer()

    if not force and (now - (lastMirror[src] or 0)) < MIRROR_EVERY then return end

    local player = rsgPlayer(src)
    if not player then return end

    local setMeta = player.Functions and player.Functions.SetMetaData
    if not setMeta then return end

    lastMirror[src] = now

    -- ⚠️ A separate pcall around each: a build that rejects one key must not take the other down.
    if needs.hunger then pcall(setMeta, 'hunger', math.floor(needs.hunger + 0.5)) end
    if needs.thirst then pcall(setMeta, 'thirst', math.floor(needs.thirst + 0.5)) end
end

AddEventHandler('playerDropped', function()
    lastMirror[source] = nil
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /fwdebug (server) -- deliberately the same name as the client command
--
-- ★ The fault may be on either side, and one name means whoever is diagnosing does
--   not have to remember which: they type it in the console and the server answers,
--   they type it in game and the client answers.
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('fwdebug', function(source)
    local src = source

    local function line(label, ok, detail)
        print(('%s %-32s %s'):format(ok and '^2[v]^7' or '^1[x]^7', label, detail or ''))
    end

    print('^3== w_hud - FRAMEWORK DIAGNOSTIC (server) ================^0')

    local name = w.framework.core
    local okReady, ready = pcall(function() return exports.w_lib:FwReady() end)
    line('framework detected', name ~= nil, tostring(name))
    line('w_lib detection settled', okReady and ready == true, '')

    local okCid, cid = pcall(function()
        return src ~= 0 and exports.w_lib:FwGetCharacterIdentifier(src) or nil
    end)
    line('character identifier', okCid and cid, tostring(cid))

    if src ~= 0 then
        local okMoney, money = pcall(function() return exports.w_lib:FwGetMoney(src) end)
        local okGold, gold = pcall(function() return exports.w_lib:FwGetGold(src) end)
        line('FwGetMoney / FwGetGold', okMoney and okGold,
            ('cash=%s gold=%s'):format(tostring(money), tostring(gold)))
    end

    if frameworkIsRSG() then
        local player = rsgPlayer(src)
        line('RSG player object', player ~= nil, '')

        if player then
            local md = player.PlayerData.metadata or {}
            line('metadata mirror', true,
                ('hunger=%s thirst=%s'):format(tostring(md.hunger), tostring(md.thirst)))
        end

        local needs = src ~= 0 and exports.w_hud:GetNeeds(src) or nil
        line('w_hud owns', needs ~= nil,
            needs and ('hunger=%s thirst=%s'):format(needs.hunger, needs.thirst) or '')

        print('^7  the two rows above should agree within ~5s (mirror throttle)^0')
    else
        line('vorp_metabolism disabled', GetResourceState('vorp_metabolism') ~= 'started',
            GetResourceState('vorp_metabolism'))
        print('^7  vorp keeps no needs in core - nothing to mirror, by design^0')
    end

    print('^3════════════════════════════════════════════════════^0')
end, true)
