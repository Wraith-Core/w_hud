-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- needs on the client
--   Buffs · display settings · vorp_metabolism compatibility
--
--   Every value arrives from the server (w_hud:client:needs); nothing is edited here.
--
-- ★ The stress, toxicity, bladder and bowel sections were removed entirely at the
--   owner's request.
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- Receiving needs from the server
-- ════════════════════════════════════════════════════════════════════════════
RegisterNetEvent('w_hud:client:needs', function(n)
    if type(n) ~= 'table' then return end

    hunger = n.hunger or hunger
    thirst = n.thirst or thirst
    buffs  = n.buffs or {}
end)


-- ════════════════════════════════════════════════════════════════════════════
-- 4. Buffs -- the ones that touch the ped itself
--   (the ones that touch needs -- calming and feeding -- are applied by the server loop)
-- ════════════════════════════════════════════════════════════════════════════
local function horseOf()
    local h = Citizen.InvokeNative(0x4C8B59171957BCF7, cache.ped) -- GetLastMount
    if not h or h == 0 or not DoesEntityExist(h) then return nil end
    return h
end

CreateThread(function()
    while true do
        Wait((Config.Buffs and Config.Buffs.TickInterval) or 2000)

        if Config.Systems.buffs and LocalPlayer.state.isLoggedIn and type(buffs) == 'table' then
            -- recovery: entity health
            if (buffs.health or 0) > 0 then
                local h = GetEntityHealth(cache.ped)
                if h > 0 and h < GetEntityMaxHealth(cache.ped) then
                    SetEntityHealth(cache.ped, h + (Config.Buffs.health.amount or 10), 0)
                end
            end

            -- energy: stamina core
            if (buffs.energy or 0) > 0 then
                local v = GetAttributeCoreValue(cache.ped, 1) + (Config.Buffs.energy.amount or 5)
                Citizen.InvokeNative(0xC6258F41D86676E0, cache.ped, 1, v > 100 and 100 or v)
            end

            -- vigor: health core
            if (buffs.vigor or 0) > 0 then
                local v = GetAttributeCoreValue(cache.ped, 0) + (Config.Buffs.vigor.amount or 3)
                Citizen.InvokeNative(0xC6258F41D86676E0, cache.ped, 0, v > 100 and 100 or v)
            end

            -- cowboy: stamina of the last horse ridden
            if (buffs.cowboy or 0) > 0 then
                local horse = horseOf()

                if horse then
                    local now = Citizen.InvokeNative(0x775A1CA7893AA8B5, horse, Citizen.ResultAsFloat())
                    local max = Citizen.InvokeNative(0xCB42AFE2B613EE55, horse, Citizen.ResultAsFloat())

                    if now and max and now < max then
                        Citizen.InvokeNative(0xC3D4B754C0E86B9E, horse,
                            now + (Config.Buffs.cowboy.amount or 1000.0))
                    end
                end
            end
        end
    end
end)

-- Granting a buff from another client-side script
RegisterNetEvent('w_hud:client:giveBuff', function(kind, amount)
    TriggerServerEvent('w_hud:server:giveBuff', kind, amount)
end)

-- -- legacy script events (qbr-hud) -- kept working exactly as before ---------
RegisterNetEvent('givebufftoplayerhealth', function(a) TriggerServerEvent('w_hud:server:giveBuff', 'health', a) end)
RegisterNetEvent('givebufftoplayercowboy', function(a) TriggerServerEvent('w_hud:server:giveBuff', 'cowboy', a) end)
RegisterNetEvent('givebufftoplayervegan', function(a) TriggerServerEvent('w_hud:server:giveBuff', 'vegan', a) end)

-- ════════════════════════════════════════════════════════════════════════════
-- 5. vorp_metabolism compatibility
--
--   We disabled that resource, but a great many scripts written for VORP still fire
--   its events -- vorp_core first among them: respawnsystem.lua refills hunger and
--   thirst after a revive through exactly these. Without this layer the player gets
--   up from death as hungry as they died.
--
--   ★ VORP's scale is 0-1000 and ours is 0-100, so we divide by ten.
-- ════════════════════════════════════════════════════════════════════════════
-- ★ VORP's `metabolism` mapped to our toxicity, which is gone -- only the two needs remain.
local VORP_KEYS = {
    thirst = 'thirst', hunger = 'hunger',
}

local function vorpKey(key)
    return VORP_KEYS[tostring(key or ''):lower()]
end

RegisterNetEvent('vorpmetabolism:changeValue', function(key, value)
    local need = vorpKey(key); if not need then return end
    TriggerServerEvent('w_hud:server:vorpCompat', 'add', need, (tonumber(value) or 0) / 10)
end)

RegisterNetEvent('vorpmetabolism:setValue', function(key, value)
    local need = vorpKey(key); if not need then return end
    TriggerServerEvent('w_hud:server:vorpCompat', 'set', need, (tonumber(value) or 0) / 10)
end)

RegisterNetEvent('vorpmetabolism:getValue', function(key, cb)
    local need = vorpKey(key)
    if not need or type(cb) ~= 'function' then return end

    local v = (need == 'thirst') and thirst or hunger
    cb((v or 0) * 10)
end)

-- Show/hide the HUD through the old VORP interface
RegisterNetEvent('vorpmetabolism:setHud', function(enable)
    showUI = enable and true or false
end)

-- Revive after getting up from death.
-- ★ Slightly delayed: the event sometimes precedes the new character load, so the write is lost.
local function onRespawn()
    CreateThread(function()
        Wait(1500)
        TriggerServerEvent('w_hud:server:respawn')
    end)
end

RegisterNetEvent('vorp:PlayerForceRespawn', onRespawn)   -- VORP: from vorp_core

-- ⚠️ RSG has no revive event in its core. This is the name w_ambulancejob (and w_admin's
--   revive) fire on this server; if your medic resource fires something else, add it here.
RegisterNetEvent('hospital:client:Revive', onRespawn)

-- ════════════════════════════════════════════════════════════════════════════
-- 6. Telling the UI about the display settings
--   ★ This is the seam the player settings panel will use later: all the panel needs
--     to do is edit Config.Display then fire w_hud:client:refreshDisplay, and the
--     whole UI changes without touching React.
-- ════════════════════════════════════════════════════════════════════════════
local function sendDisplay()
    local buffMeta = {}

    for kind, cfg in pairs(Config.Buffs or {}) do
        if type(cfg) == 'table' and cfg.label then
            buffMeta[kind] = {
                label = locale(cfg.label), -- a dictionary key (buff.<kind>)
                color = cfg.color or '#F2F2F2', -- still sent; the chip is drawn in paper whatever it says (App.tsx BuffRow)
            }
        end
    end

    SendNUIMessage({
        action = 'setDisplay',
        display = Config.Display or {},
        -- thresholds travel with the settings in one message: the coming panel will set both together
        thresholds = Config.Thresholds or {},
        buffMeta = buffMeta,
    })
end

CreateThread(function()
    Wait(800)
    sendDisplay()
end)

RegisterNetEvent('w_hud:client:refreshDisplay', sendDisplay)
exports('RefreshDisplay', sendDisplay)

--- Toggle a HUD element at runtime (called by the player settings panel)
exports('SetDisplay', function(key, patch)
    if type(key) ~= 'string' or type(patch) ~= 'table' then return false end

    Config.Display = Config.Display or {}
    Config.Display[key] = Config.Display[key] or {}

    for k, v in pairs(patch) do Config.Display[key][k] = v end

    sendDisplay()
    return true
end)

-- ════════════════════════════════════════════════════════════════════════════
-- 7. Public interface for other resources
-- ════════════════════════════════════════════════════════════════════════════
exports('GetNeeds', function()
    return {
        hunger = hunger, thirst = thirst, cleanliness = cleanliness, buffs = buffs,
    }
end)

exports('GetBuffs', function() return buffs or {} end)

-- ════════════════════════════════════════════════════════════════════════════
-- /hudall -- show every core at once
--
-- ★ For previewing and tuning: conditional cores only appear above their threshold,
--   and the horse cores only while mounted -- so reviewing the whole design used to
--   require being hungry and mounted at the same time. This command bypasses all of
--   that without changing a single value.
--
--   ⚠️ Display only: it does not touch your needs and is not persisted. Leaving resets it.
-- ════════════════════════════════════════════════════════════════════════════
local previewOn = false

RegisterCommand('hudall', function(_, args)
    local arg = tostring(args[1] or ''):lower()

    if arg == 'on' then previewOn = true
    elseif arg == 'off' then previewOn = false
    else previewOn = not previewOn end

    SendNUIMessage({ action = 'setPreview', on = previewOn })

    w.print.info(('preview %s - %s'):format(
        previewOn and 'ON' or 'OFF',
        previewOn and 'all cores visible regardless of thresholds'
        or 'back to normal visibility rules'))
end, false)
