-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · client/framework.lua
-- Everything framework-facing in one place -- VORP and RSG/QBR
--
-- ★ Why one file instead of scattered lines?
--
--   The VORP events used to be spread between client/event.lua and
--   client/metabolism.lua, so anyone asking 'what does the HUD read from the
--   framework?' read two files and still got no answer. Worse, adding RSG that
--   way would have meant a second scattering on top of the first.
--
--   Here there is one line per event per framework, side by side. And what has
--   no counterpart is written down as having none -- which is more useful than a
--   silent absence.
--
-- ═══ The table ═══
--
--   What                 VORP                        RSG / QBR
--   ---------------------------------------------------------------------------
--   Top-right panel      vorp:updateUi               RSGCore:Player:SetPlayerData
--   PVP state            vorp:setPVPUi               RSGCore:Client:PvpHasToggled
--   Money change         vorp:updateUi               RSGCore:Client:OnMoneyChange
--   Character login      vorp:SelectedCharacter      RSGCore:Client:OnPlayerLoaded
--   Character logout     vorp:playerUnloaded         RSGCore:Client:OnPlayerUnload
--
--   (The last two live in client/metabolism.lua with the rest of the lifecycle.)
--
-- ⚠️ We register both frameworks' events unconditionally. An absent framework's
--   event is never fired, so registering costs nothing -- while a condition broke
--   the one case that needs it: a server where w_hud starts before framework
--   detection has settled.
-- ════════════════════════════════════════════════════════════════════════════

--- Top-right panel. Missing fields are sent as nil, not zero:
--- ★ Zero is a number that gets displayed; absence hides the row. tokens=0 on RSG
---   read as 'you have zero tokens' -- a currency that does not exist there at all.
--- The player's level, from w_level's state bag (Player(src).state.w_level = { level, xp, ... }).
--- nil while w_level has not published (no such resource, or the row not loaded yet).
---@return number|nil
local function levelOf()
    local ok, state = pcall(function() return LocalPlayer.state and LocalPlayer.state.w_level end)
    if ok and type(state) == 'table' and state.level ~= nil then return tonumber(state.level) end
    return nil
end

---@param d table
local function pushInfo(d)
    SendNUIMessage({
        action = 'fwInfo',
        tokens = d.tokens,
        gold   = d.gold,
        cash   = d.cash,
        dirty  = d.dirty,
        bank   = d.bank,
        xp     = d.xp,
        level  = levelOf(),
        id     = d.id,
    })
end

-- ★ The level row used to be vorp's xp in thousands -- a number nobody earns here, so it
--   printed 0 beside a level-100 player. It is w_level's level now: read from the state bag
--   with every panel refresh above, and pushed on its own the moment the bag changes (the row
--   loads, a level-up, an admin /setlevel), so the HUD never waits for the next purchase.
AddStateBagChangeHandler('w_level', nil, function(bagName, _key, value)
    if bagName ~= ('player:' .. GetPlayerServerId(PlayerId())) then return end
    SendNUIMessage({ action = 'fwLevel', level = type(value) == 'table' and tonumber(value.level) or nil })
end)
-- and once the page is up (it may have mounted after the bag was set): metabolism.lua answers
-- w_hud:ready and raises this local event for the rest of the client
AddEventHandler('w_hud:client:pageReady', function()
    local level = levelOf()
    if level ~= nil then SendNUIMessage({ action = 'fwLevel', level = level }) end
end)

local function pushPvp(active)
    SendNUIMessage({ action = 'fwPvp', pvp = active and true or false })
end

-- ════════════════════════════════════════════════════════════════════════════
-- VORP
-- ════════════════════════════════════════════════════════════════════════════

-- ★ Time throttle: vorp_core fires updateUi on every currency change, and a single
--   purchase may fire three (cash + gold + tokens). Without it, three server round trips.
local lastVorpSync = 0

RegisterNetEvent('vorp:updateUi', function(stringJson)
    local now = GetGameTimer()

    if now - lastVorpSync >= 150 then
        lastVorpSync = now
        TriggerServerEvent('w_hud:server:updateMoney')
    end

    local ok, d = pcall(function() return json.decode(stringJson) end)
    if not ok or type(d) ~= 'table' or d.action ~= 'update' then return end

    -- ★ The dirty money rides along with the rest: vorp_core already puts
    --   blackmoneyquanty in this very payload, so it costs nothing and lands
    --   instantly -- no waiting for the server's next bank read.
    --   The bank is not here, and cannot be: it lives in bank_users, not on the
    --   character. It arrives through w_hud:client:updateMoney instead.
    pushInfo({
        tokens = d.rolquanty,
        gold   = d.goldquanty,
        cash   = d.moneyquanty,
        dirty  = d.blackmoneyquanty,
        xp     = d.xp,
        id     = d.serverId,
    })
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The bank moved -- read it now rather than at the next cache expiry
--
-- vorp_banking changes bank_users in a dozen places and announces only one of
-- them, so this is a nudge and not the whole story: the per-second refresh in
-- client/thread.lua still catches everything else within BANK_TTL.
-- ════════════════════════════════════════════════════════════════════════════
RegisterNetEvent('vorp_bank:client:updateBalance', function()
    TriggerServerEvent('w_hud:server:refreshBank')
end)

RegisterNetEvent('vorp:setPVPUi', function(active)
    pushPvp(active)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- RSG / QBR
--
-- ★ RSG has no gold, no tokens and no XP. Its two currencies are cash and bloodmoney
--   (plus banks, which are no business of a HUD). Mapping bloodmoney onto the 'gold'
--   slot is not arbitrary: exports.w_lib:FwGetGold does exactly the same, and diverging
--   would have the HUD show one number and the inventory another for one currency.
-- ════════════════════════════════════════════════════════════════════════════

---@param pd table RSG player data
local function fromRsgPlayerData(pd)
    if type(pd) ~= 'table' then return end

    local money = pd.money or {}

    pushInfo({
        tokens = nil,                       -- no counterpart in RSG
        gold   = money.gold or money.bloodmoney or 0,
        cash   = money.cash or 0,
        dirty  = nil,                       -- RSG maps its bloodmoney onto gold above
        bank   = money.bank,                -- RSG carries the bank in player data
        xp     = nil,                       -- no counterpart (rep is a table, not a number)
        id     = pd.citizenid,
    })
end

RegisterNetEvent('RSGCore:Player:SetPlayerData', fromRsgPlayerData)

-- ★ A second money event on purpose even though SetPlayerData covers it: rsg-core
--   builds differ, and some fire OnMoneyChange alone for small changes. The overlap
--   throttles itself (the line below) so it costs nothing, and its absence means a
--   frozen number.
local lastRsgSync = 0

RegisterNetEvent('RSGCore:Client:OnMoneyChange', function()
    local now = GetGameTimer()
    if now - lastRsgSync < 150 then return end
    lastRsgSync = now

    TriggerServerEvent('w_hud:server:updateMoney')

    -- and read the panel straight from local data -- faster than waiting for the server
    local ok, pd = pcall(function() return exports.w_lib:FwGetPlayerData() end)
    if ok then fromRsgPlayerData(pd) end
end)

RegisterNetEvent('RSGCore:Client:PvpHasToggled', function(enabled)
    pushPvp(enabled)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- First fill
--
-- ⚠️ These events fire on **change**, not on login. So a player who has not spent
--   anything since logging in had an empty panel until their first transaction. We
--   read it once as soon as things are ready.
--
--   VORP keeps no local player data (FwGetPlayerData returns nil there), so we settle
--   for asking the server for money -- the rest arrives with the first updateUi.
-- ════════════════════════════════════════════════════════════════════════════
--- RSG and QBR together -- one PlayerData contract (citizenid · money · metadata).
local function isRsgFamily()
    return w.framework:is('rsg') or w.framework:is('qbr')
end

local function primeInfo()
    if isRsgFamily() then
        local ok, pd = pcall(function() return exports.w_lib:FwGetPlayerData() end)
        if ok and pd then fromRsgPlayerData(pd) end
    end

    TriggerServerEvent('w_hud:server:updateMoney')
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    CreateThread(function() Wait(1200); primeInfo() end)
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    CreateThread(function() Wait(1200); primeInfo() end)
end)

-- Live resource restart: no login event is replayed, so the server pushes this.
RegisterNetEvent('w_hud:client:forceLoaded', function()
    CreateThread(function() Wait(600); primeInfo() end)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /fwdebug -- which framework are we on, and what is actually arriving from it?
--
-- ★ A framework fault does not announce itself: the panel stays empty or the number
--   freezes, and the cause may be detection, the event, or the bridge -- three causes
--   with one symptom.
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('fwdebug', function()
    local function line(label, ok, detail)
        print(('%s %-32s %s'):format(ok and '^2[v]^7' or '^1[x]^7', label, detail or ''))
    end

    print('^3== w_hud - FRAMEWORK DIAGNOSTIC =========================^0')

    local name = w.framework.core
    local okReady, ready = pcall(function() return exports.w_lib:FwReady() end)
    ready = okReady and ready == true

    line('framework detected', name ~= nil, tostring(name))
    line('w_lib detection settled', ready, ready and '' or '^3still probing^7')
    line('core object', w.framework:getCore() ~= nil, '')

    for _, res in ipairs({ 'w_core', 'vorp_core', 'rsg-core', 'qbr-core', 'w_lib', 'w_inventory' }) do
        line('resource ' .. res, GetResourceState(res) == 'started', GetResourceState(res))
    end

    if isRsgFamily() then
        local ok, pd = pcall(function() return exports.w_lib:FwGetPlayerData() end)
        line('FwGetPlayerData', ok and type(pd) == 'table',
            (ok and type(pd) == 'table')
                and ('citizenid=%s cash=%s bloodmoney=%s')
                    :format(tostring(pd.citizenid),
                            tostring((pd.money or {}).cash),
                            tostring((pd.money or {}).bloodmoney))
                or '^1no player data - character not loaded?^7')
    elseif w.framework:is('vorp') then
        print('^7  vorp keeps no local player data - the panel fills from vorp:updateUi^0')
    end

    line('character loaded', LocalPlayer.state.isLoggedIn == true, '')
    print('^3════════════════════════════════════════════════════^0')
end, false)
