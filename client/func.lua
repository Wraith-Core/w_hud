-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · client/func.lua -- small helpers shared by the client files
-- ════════════════════════════════════════════════════════════════════════════

-- ── the language, as the library decides it ─────────────────────────────────
-- Allowed values are 'ar' and 'en' only; anything else the library may report is 'en'.
WHudLocale = {}

--- 'ar' or 'en' from whatever the library reports.
---@param key any
---@return 'ar' | 'en'
function WHudLocale.normalise(key)
    return (tostring(key or ''):lower() == 'ar') and 'ar' or 'en'
end

---@return 'ar' | 'en'
function WHudLocale.key()
    local ok, key = pcall(function() return w.getLocaleKey() end)
    return WHudLocale.normalise(ok and key or nil)
end

---@return boolean
function WHudLocale.rtl()
    return WHudLocale.key() == 'ar'
end

--- The display name of an item: our dictionary first (item.<name>), else what the
--- active inventory calls it.
---@param item string
---@return string
function WHudLocale.itemLabel(item)
    local key = 'item.' .. tostring(item)
    local label = locale(key)
    if label ~= key then return label end

    local ok, name = pcall(function() return exports.w_lib:InvItemLabel(item) end)
    return (ok and type(name) == 'string' and name ~= '') and name or tostring(item)
end

--- The bare centred notice this HUD uses for its own messages (no plate, a colour per
--- meaning). `title` is a dictionary key (formatted with `args` when given) or an already
--- translated string; `description` is shown as it is (numbers, a level counter).
---@param title string
---@param color? string
---@param icon? string
---@param duration? number
---@param args? table format arguments for the title key
---@param description? string
function WHudLocale.notify(title, color, icon, duration, args, description)
    if not title then return end

    local text = (type(args) == 'table' and #args > 0)
        and locale(title, table.unpack(args))
        or locale(title)

    w.notify({
        title = text, description = description or '', icon = icon or 'tick',
        placement = 'middle-right', duration = duration or 5000, useBackground = false,
        contentAlignment = 'center', isRTL = WHudLocale.rtl(),
        titleColor = color or '#34b895', descriptionColor = 'rgba(255,255,255,0.8)',
    })
end

--- A notice sent by our server side: a dictionary key (+ format args) translated here,
--- in the player's own language and text direction. The server only knows the convar.
RegisterNetEvent('w_hud:client:notice', function(data)
    if type(data) ~= 'table' or type(data.title) ~= 'string' then return end

    WHudLocale.notify(data.title, data.color, data.icon, data.duration, data.args, data.description)
end)

function showHorseUi(horseHealth, text, distance)
    local ped = cache.ped
    local playerCoords = GetEntityCoords(ped)
    local playerHeading = GetEntityHeading(ped)
    local offsetX = -0.2
    local offsetZ = 0.5
    local offsetY = 0.1 * math.sin(math.rad(playerHeading))
    local x = playerCoords.x + offsetX
    local y = playerCoords.y + offsetY
    local z = playerCoords.z + offsetZ
    local _, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    SendNUIMessage({
        type = "onHorse",
        x = screenX,
        y = screenY,
        text = text,
        horseHealth = horseHealth,
        distance = distance
    })
end

exports("getAllValues", function()
    return {
        health = w.player.healthPercent(),
        hunger = hunger,
        thirst = thirst,
        temperature = temperature,
    }
end)

-- (WHudKeyOff, from client/bisect.lua's /hudkeys, takes single entries out at runtime)
function DisableKeys()
    local off = WHudKeyOff
    for _, key in pairs(Config.KeysDisabled) do
        if not off or not off[key] then DisableControlAction(0, key, false) end
    end
end

-- ★ GetShakeIntensity and GetEffectInterval went out with the stress system --
--   they served it alone, and nothing calls them now.

local fliesHandle = false

FliesSpawn = function(clean)
    local dict, name = 'core', 'env_flies'

    if clean <= Config.MinCleanliness then
        if fliesHandle then return end

        -- the library requests the asset and waits for it (errors after the timeout)
        local ok = pcall(w.requestNamedPtfxAsset, dict, 3000)
        if not ok then return w.print.warn('could not load the flies ptfx dictionary') end

        Citizen.InvokeNative(0xA10DB07FC234DD12, dict) -- UseParticleFxAsset
        fliesHandle = Citizen.InvokeNative(0x9C56621462FFE7A6, name, cache.ped, -- StartParticleFxLoopedOnEntityBone
            0.0, 0.0, 0.0, -90.0, 0.0, 0.0, 464, 1.0, 0, 0, 0)
    elseif fliesHandle then
        if Citizen.InvokeNative(0x9DD5AFF561E88F2A, fliesHandle) then -- DoesParticleFxLoopedExist
            Citizen.InvokeNative(0x459598F579C98929, fliesHandle, false) -- StopParticleFxLooped
        end
        fliesHandle = false
    end
end

-- ════════════════════════════════════════════════════════════════════════════
-- Stamina as the HUD draws it
--
-- ═══ Why the stamina core was red forever ═══
--
--   _GET_PLAYER_STAMINA (0x0FF421E467373FCF) is not a percentage. It answers the bar in
--   engine units, and the bar's ceiling is 11.2 per STAMINA_TANK_1 level: 11.2 on a fresh
--   character, 112.0 only at tank 10. The RSG HUD this code grew from sent it raw because
--   rsg-essentials (client/maxcores.lua) raised every player to tank 10 on join. That file
--   did not survive the move to the w_* resources, so here a FULL bar read 11.2 -- under
--   the red line (Config.Thresholds.dangerLow = 20) -- and no heal, revive, meal or admin
--   "infinite stamina" could ever lift it. The same raw number went into the state bag, so
--   w_admin's player list showed ~11% stamina after every heal as well.
--
--   So the bar is divided by its own ceiling. _GET_PED_MAX_STAMINA answers the core's fixed
--   reserve (22.4) plus that ceiling; the highest reading seen this session backs it up in
--   case a build answers something else. The smaller of the two wins, and a reading above
--   both raises the ceiling, so a full bar always reads 100 and never more.
-- ════════════════════════════════════════════════════════════════════════════
WHudStamina = { peak = 0.0 }

local STAMINA_CORE_RESERVE = 22.4 -- the part of _GET_PED_MAX_STAMINA that is not the bar
local STAMINA_TANK_STEP    = 11.2 -- the bar per STAMINA_TANK_1 level; a fresh character has one

--- The stamina bar (the ring) as a true 0-100 percentage.
---@return number percent, number raw, number ceiling, number pedMax
function WHudStamina.barPercent()
    local raw = tonumber(Citizen.InvokeNative(0x0FF421E467373FCF, cache.playerId, Citizen.ResultAsFloat())) or 0.0
    if raw ~= raw or raw < 0.0 then raw = 0.0 end -- NaN or garbage while the ped is swapped
    if raw > WHudStamina.peak then WHudStamina.peak = raw end

    local pedMax = tonumber(Citizen.InvokeNative(0xCB42AFE2B613EE55, cache.ped, Citizen.ResultAsFloat())) or 0.0
    if pedMax ~= pedMax then pedMax = 0.0 end

    local ceiling = math.max(WHudStamina.peak, STAMINA_TANK_STEP)
    local fromEngine = pedMax - STAMINA_CORE_RESERVE
    if fromEngine >= STAMINA_TANK_STEP and fromEngine < ceiling then ceiling = fromEngine end
    if raw > ceiling then ceiling = raw end

    return math.min(100.0, raw / ceiling * 100.0), raw, ceiling, pedMax
end

--- The one 0-100 value the React core is drawn from (web/src/App.tsx, Core): its upper half
--- is the ring and its lower half the icon. In RDR the stamina ring is the bar and the icon
--- is the core, and the bar is spent first -- so while the bar holds anything the value sits
--- in the upper half, and only an empty bar hands the icon to the core. That keeps the colour
--- on the core, as RDR does: a sprint that empties the ring stays white, and only a core that
--- is itself running low (poison, an engine drain nobody fed) turns yellow and then red.
---@param bar? number the bar percentage, when the caller already read it
---@param core? number the stamina core 0-100, when the caller already read it
---@return number
function WHudStamina.hudValue(bar, core)
    bar = tonumber(bar) or WHudStamina.barPercent()

    -- under one percent the ring draws nothing anyway, and the state bag rounds it to zero
    if bar >= 1.0 then return 50.0 + bar / 2.0 end

    core = tonumber(core) or tonumber(GetAttributeCoreValue(cache.ped, 1)) or 0
    if core < 0 then core = 0 elseif core > 100 then core = 100 end
    return core / 2.0
end

-- /staminadiag -- what the engine answers and what the HUD makes of it, in one line.
RegisterCommand('staminadiag', function()
    local bar, raw, ceiling, pedMax = WHudStamina.barPercent()
    -- floored: %d throws on a float with no integer representation
    local core = math.floor(tonumber(GetAttributeCoreValue(cache.ped, 1)) or 0)
    print(('^3[w_hud]^7 stamina: raw %.2f / ceiling %.2f (ped max %.2f, peak %.2f) = bar %.0f%% · core %d · hud %.0f^0')
        :format(raw, ceiling, pedMax, WHudStamina.peak, bar, core, WHudStamina.hudValue(bar, core)))
end, false)

function showui(bool, bool2)
    local stamina = tonumber(string.format("%.2f", WHudStamina.hudValue()))
    local MenuActive = IsPauseMenuActive()
    local Cinematic = Citizen.InvokeNative(0xBF7C780731AADBF8, true)
    local MAP = Citizen.InvokeNative(0x25B7A0206BDFAC76, GetHashKey("MAP"))
    if MenuActive or Cinematic or MAP then
        show = bool
        -- Ensure cash/gold are numbers and not nil before sending
        local formattedCash = 0.0
        if cash then
            formattedCash = tonumber(cash) or 0.0
        end

        local formattedGold = 0.0
        if gold then
            formattedGold = tonumber(gold) or 0.0
        end

        SendNUIMessage({
            action = 'hudtick',
            stamina = stamina,
            show = show,
            cash = tonumber(string.format("%.2f", formattedCash)),
            gold = tonumber(string.format("%.2f", formattedGold)),
        })
    else
        show = bool2
    end
end

exports('showui', showui)

function hidePlayerAtCoords()
    local ped = cache.ped
    SetEntityCoords(ped, Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false)
    NetworkSetEntityOnlyExistsForParticipants(ped, true)
end

-- Restore player visibility after hiding
function showPlayerFromHide()
    local ped = cache.ped
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true)
    NetworkSetEntityOnlyExistsForParticipants(ped, false)
end

function StartFade(timer)
    DoScreenFadeOut(timer)
    while IsScreenFadingOut() do
        Wait(1)
    end
end

function EndFade(timer)
    ShutdownLoadingScreen()
    DoScreenFadeIn(timer)
    while IsScreenFadingIn() do
        Citizen.Wait(1)
    end
end
