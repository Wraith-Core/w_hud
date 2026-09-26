CreateThread(function()
    while true do
        local newWeather = GetPrevWeatherTypeHashName()
        if newWeather ~= currentWeather then
            currentWeather = newWeather
            TriggerEvent('hud:client:UpdateWeather', currentWeather)
        end
        Wait(1000)
    end
end)
CreateThread(function()
    while true do
        Wait(0)
        if not WHudBisect or WHudBisect.keys ~= false then DisableKeys() end
    end
end)


-- Compass follows the camera heading -- works on foot and mounted alike
CreateThread(function()
    local last = -999.0
    while true do
        local camRot = GetGameplayCamRot(2)
        local heading = (camRot and camRot.z) or GetEntityHeading(cache.ped)
        local compassAngle = (360.0 - heading) % 360.0
        if math.abs(compassAngle - last) > 0.3 and (not WHudBisect or WHudBisect.nui ~= false) then
            last = compassAngle
            SendNUIMessage({ comp = 'setCompassDirection', compassDirection = compassAngle })
        end
        Wait(0)
    end
end)

CreateThread(function()
    if Config.HidePlayerHealthNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 4, 2)
        Citizen.InvokeNative(0xC116E6DF68DCE667, 5, 2)
    end
    if Config.HidePlayerStaminaNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 0, 2)
        Citizen.InvokeNative(0xC116E6DF68DCE667, 1, 2)
    end
    if Config.HidePlayerDeadEyeNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 2, 2)
        Citizen.InvokeNative(0xC116E6DF68DCE667, 3, 2)
    end
    if Config.HideHorseHealthNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 6, 2)
        Citizen.InvokeNative(0xC116E6DF68DCE667, 7, 2)
    end
    if Config.HideHorseStaminaNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 8, 2)
        Citizen.InvokeNative(0xC116E6DF68DCE667, 9, 2)
    end
    if Config.HideHorseCourageNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 10, 2)
        Citizen.InvokeNative(0xC116E6DF68DCE667, 11, 2)
    end
end)



CreateThread(function()
    while true do
        Wait(1000)
        TriggerServerEvent('w_hud:server:updateMoney')
    end
end)

local lastSyncedStamina = -1
local lastStaminaSyncTimer = 0

CreateThread(function()
    while true do
        Wait(50)
        if LocalPlayer.state.isLoggedIn and incinematic == false and inBathing == false and inClothing == false and showUI and not hideStement then
            -- ★ The bar as a true percentage -- the raw reading tops out at 11.2 on a fresh
            --   character and read as permanently red (WHudStamina in client/func.lua).
            local stamina = tonumber(string.format("%.2f", WHudStamina.barPercent()))
            local now = GetGameTimer()
            if (now - lastStaminaSyncTimer > 1000 and math.abs(stamina - lastSyncedStamina) >= 1.0) or math.abs(stamina - lastSyncedStamina) >= 5.0 then
                lastSyncedStamina = stamina
                lastStaminaSyncTimer = now
                LocalPlayer.state:set('stamina', math.floor(stamina), true)
            end
            local mounted = IsPedOnMount(cache.ped)

            -- ★ Two values per need, as in RDR: the outer ring is one value and the
            --   inner icon another that drains alongside it.
            --   GetAttributeCoreValue(ped, 0) = health core · 1 = stamina core
            local healthCore  = GetAttributeCoreValue(cache.ped, 0)
            local staminaCore = GetAttributeCoreValue(cache.ped, 1)
            showui(false, true)
            local voice = 0
            -- Cfx Mumble native (RedM); some builds answer 1/0 rather than a boolean
            local talkingRaw = MumbleIsPlayerTalking(cache.playerId)
            local talking = talkingRaw == true or talkingRaw == 1
            if LocalPlayer.state['proximity'] then
                voice = LocalPlayer.state['proximity'].distance
            end

            local horsehealth = 0
            local horsestamina = 0
            local horsehealthCore = 0
            local horsestaminaCore = 0
            local horseclean = 0
            if mounted then
                local horse = GetMount(cache.ped)
                local maxHealth = Citizen.InvokeNative(0x4700A416E8324EF3, horse, Citizen.ResultAsInteger())
                local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, horse, Citizen.ResultAsFloat())
                local horseCleanliness = Citizen.InvokeNative(0x147149F2E909323C, horse, 16, Citizen.ResultAsInteger())
                if horseCleanliness == 0 then
                    horseclean = 100
                else
                    horseclean = 100 - horseCleanliness
                end
                horsehealth = tonumber(string.format("%.2f",
                    Citizen.InvokeNative(0x82368787EA73C0F7, horse) / maxHealth * 100))
                horsestamina = tonumber(string.format("%.2f",
                    Citizen.InvokeNative(0x775A1CA7893AA8B5, horse, Citizen.ResultAsFloat()) / maxStamina * 100))
                horsehealthCore = GetAttributeCoreValue(horse, 0)
                horsestaminaCore = GetAttributeCoreValue(horse, 1)
            end

            local pvpstatus = GetRelationshipBetweenGroups(PLAYER, PLAYER)

            if pvpstatus == 5 then
                pvp = true
            else
                pvp = false
            end
            if WHudBisect and WHudBisect.radar == false then
                -- /hudbisect radar off: no radar write from here
            elseif not hideStement then
                w.setRadarVisible(true)
            else
                DisplayRadar(false)
            end

            -- Ensure cash/gold are numbers and not nil before sending
            local formattedCash = 0.0
            if cash then
                formattedCash = tonumber(cash) or 0.0
            end

            local formattedGold = 0.0
            if gold then
                formattedGold = tonumber(gold) or 0.0
            end

            local formattedBank = tonumber(bank) or 0.0
            local formattedDirty = tonumber(dirty) or 0.0

            if not WHudBisect or WHudBisect.nui ~= false then SendNUIMessage(WHudDev.apply({
                action = 'hudtick',
                show = show,
                cash = tonumber(string.format("%.2f", formattedCash)),
                gold = tonumber(string.format("%.2f", formattedGold)),
                bank = tonumber(string.format("%.2f", formattedBank)),
                dirty = tonumber(string.format("%.2f", formattedDirty)),
                health = w.player.healthPercent(),
                healthCore = healthCore,
                -- the ring is the bar, the icon the core (WHudStamina.hudValue)
                stamina = WHudStamina.hudValue(stamina, staminaCore),
                staminaCore = staminaCore,
                thirst = thirst,
                hunger = hunger,
                cleanliness = cleanliness,
                -- full needs (server/metabolism.lua) + buffs
                buffs = buffs,
                -- ★ nil while nothing is gilded, so the payload fingerprint stays quiet.
                --   The ridden horse is passed in: its boosters (w_stables) ride along.
                gilded = WHudGold and WHudGold.snapshot(mounted and GetMount(cache.ped) or nil) or nil,
                -- ★ وكذلك التسمُّم: nil ما دام اللاعب سليماً — دائرة الصحة لا تأخذ
                --   لون السمّ إلّا حين يكون.
                poisoned = WHudPoison and WHudPoison.snapshot() or nil,
                talking = talking,
                temp = temperature,
                tempNum = temp,
                onHorse = mounted,
                horsehealth = horsehealth,
                horsestamina = horsestamina,
                horsehealthCore = horsehealthCore,
                horsestaminaCore = horsestaminaCore,
                horseclean = horseclean,
                voice = voice,
                voiceLevel = voiceLevel,
                voiceLevels = #(((Config.Voice or {}).Levels) or {}),
                youhavemail = youhavemail,
                pvp = pvp
            })) end
        else
            if WHudBisect and WHudBisect.radar == false then
                -- /hudbisect radar off: no radar write from here
            elseif not hideStement then
                w.setRadarVisible(true)
            else
                DisplayRadar(false)
            end

            -- Ensure cash/gold are numbers and not nil before sending
            local formattedCash = 0.0
            if cash then
                formattedCash = tonumber(cash) or 0.0
            end

            local formattedGold = 0.0
            if gold then
                formattedGold = tonumber(gold) or 0.0
            end

            local formattedBank = tonumber(bank) or 0.0
            local formattedDirty = tonumber(dirty) or 0.0

            if not WHudBisect or WHudBisect.nui ~= false then SendNUIMessage(WHudDev.apply({
                action = 'hudtick',
                show = false,
                cash = tonumber(string.format("%.2f", formattedCash)),
                gold = tonumber(string.format("%.2f", formattedGold)),
                bank = tonumber(string.format("%.2f", formattedBank)),
                dirty = tonumber(string.format("%.2f", formattedDirty)),
                health = w.player.healthPercent(),
                healthCore = healthCore,
                stamina = stamina,
                staminaCore = staminaCore,
                thirst = thirst,
                hunger = hunger,
                cleanliness = cleanliness,
                buffs = buffs,
                -- ★ nil while nothing is gilded, so the payload fingerprint stays quiet.
                gilded = WHudGold and WHudGold.snapshot() or nil,
                -- ★ وكذلك التسمُّم: nil ما دام اللاعب سليماً — دائرة الصحة لا تأخذ
                --   لون السمّ إلّا حين يكون.
                poisoned = WHudPoison and WHudPoison.snapshot() or nil,
                talking = talking,
                temp = temperature,
                tempNum = temp,
                onHorse = mounted,
                horsehealth = horsehealth,
                horsestamina = horsestamina,
                horsehealthCore = horsehealthCore,
                horsestaminaCore = horsestaminaCore,
                horseclean = horseclean,
                voice = voice,
                voiceLevel = voiceLevel,
                voiceLevels = #(((Config.Voice or {}).Levels) or {}),
                youhavemail = youhavemail,
                pvp = pvp
            })) end
        end
        if cleanliness ~= nil and Config.FlyEffect then
            FliesSpawn(cleanliness)
        end
    end
end)

--- What the minimap should be right now: 'off' | 'map' | 'compass'.
---
--- ★ Two authorities, and the order between them is the whole point. The player's choice
---   from the HUD panel wins when they made one; 'server' means they made none, and then
---   Config.OnFootMinimap and its three siblings decide exactly as they always did.
---
--- ⚠️ The config branch is the original logic verbatim, including its quirk: on foot the
---   map outranks the compass, so OnFootCompass is only consulted once OnFootMinimap is
---   off. Rewriting that into something tidier would change behaviour on every server
---   that has both switched on.
---@param mounted boolean
---@return string
local function minimapMode(mounted)
    -- Written out rather than as a and b or c: that idiom silently falls through to the
    -- third value whenever the second is false or nil, and a table read is exactly where
    -- that happens. Here it would mean a mounted player getting the on-foot setting.
    local choice = 'server'

    if type(WHudWorld) == 'table' then
        if mounted then
            choice = WHudWorld.mounted or 'server'
        else
            choice = WHudWorld.onFoot or 'server'
        end
    end

    if choice == 'off' or choice == 'map' or choice == 'compass' then return choice end

    if mounted then
        if not Config.MounttMinimap then return 'off' end
        return Config.MountCompass and 'compass' or 'map'
    end

    if Config.OnFootMinimap then return 'map' end
    return Config.OnFootCompass and 'compass' or 'off'
end

local appliedMinimapType, appliedRadarConfig, appliedRadarAt = nil, nil, 0
CreateThread(function()
    while true do
        Wait(500)
        mapTicks = (mapTicks or 0) + 1  -- /mapdebug reads this to know the thread is alive
        if WHudBisect and WHudBisect.radar == false then goto skip end -- /hudbisect radar off
        local interiorId = GetInteriorFromEntity(cache.ped)
        local isMounted = IsPedOnMount(cache.ped) or IsPedInAnyVehicle(cache.ped)

        -- A hidden HUD hides the map with it, whatever either authority says.
        local worldVisible = showUI and not hideStement and not incinematic and not inBathing and not inClothing and LocalPlayer.state.isLoggedIn
        local mode = worldVisible and minimapMode(isMounted) or 'off'
        w.setRadarMode(mode)

        -- ★ Write the minimap type / radar config only when the wanted value CHANGES (or every
        --   5 s as a safety net), not every 500 ms: these are persistent engine settings, and
        --   a HUD that rewrites them twice a second is one more thing every other script's UI
        --   has to survive (2026-09-18, the SS-Stable prompt hunt).
        local wantType, wantConfig
        if w.isRadarReplaced() then
            -- w_map draws both modes; keep the native layer dormant.
            wantType = 0
        elseif mode == 'compass' then
            wantType = 3
        elseif mode == 'map' then
            wantType = 1

            -- ⚠️ On foot only, as before: the radar config swap is what keeps interiors
            --    readable, and it was never applied while mounted.
            if not isMounted then
                wantConfig = interiorId ~= 0 and 0xDF5DB58C or 0x25B517BF -- RADAR_CONFIG_INDOOR / RADAR_CONFIG_CODE_CONTROL
            end
        else
            wantType = 0
        end
        local now = GetGameTimer()
        local stale = now - (appliedRadarAt or 0) > 5000
        if wantType ~= appliedMinimapType or stale then
            SetMinimapType(wantType)
            appliedMinimapType = wantType
        end
        if wantConfig and (wantConfig ~= appliedRadarConfig or stale) then
            SetRadarConfigType(wantConfig, 0)
            appliedRadarConfig = wantConfig
        end
        if stale then appliedRadarAt = now end
        ::skip::
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        local coords = GetEntityCoords(cache.ped)

        local hat = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x9925C067)
        local shirt = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x2026C46D)
        local pants = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x1D4C528A)
        local boots = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x777EC6EF)
        local coat = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xE06D30CE)
        local opencoat = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x662AC34)
        local gloves = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xEABE0032)
        local vest = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x485EE834)
        local poncho = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xAF14310B)
        local skirts = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xA0E3AB7F)
        local chaps = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x3107499B)

        if hat == 1 then
            what = Config.WearingHat
        else
            what = 0
        end
        if shirt == 1 then
            wshirt = Config.WearingShirt
        else
            wshirt = 0
        end
        if pants == 1 then
            wpants = Config.WearingPants
        else
            wpants = 0
        end
        if boots == 1 then
            wboots = Config.WearingBoots
        else
            wboots = 0
        end
        if coat == 1 then
            wcoat = Config.WearingCoat
        else
            wcoat = 0
        end
        if opencoat == 1 then
            wopencoat = Config.WearingOpenCoat
        else
            wopencoat = 0
        end
        if gloves == 1 then
            wgloves = Config.WearingGloves
        else
            wgloves = 0
        end
        if vest == 1 then
            wvest = Config.WearingVest
        else
            wvest = 0
        end
        if poncho == 1 then
            wponcho = Config.WearingPoncho
        else
            wponcho = 0
        end
        if skirts == 1 then
            wskirts = Config.WearingSkirt
        else
            wskirts = 0
        end
        if chaps == 1 then
            wchaps = Config.WearingChaps
        else
            wchaps = 0
        end

        local tempadd = (what + wshirt + wpants + wboots + wcoat + wopencoat + wgloves + wvest + wponcho + wskirts + wchaps)

        if Config.TempFormat == 'celsius' then
            temperature = math.floor(GetTemperatureAtCoords(coords)) + tempadd .. "°C"
            temp = math.floor(GetTemperatureAtCoords(coords)) + tempadd
        end
        if Config.TempFormat == 'fahrenheit' then
            temperature = math.floor(GetTemperatureAtCoords(coords) * 9 / 5 + 32) + tempadd .. "°F"
            temp = math.floor(GetTemperatureAtCoords(coords) * 9 / 5 + 32) + tempadd
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        if LocalPlayer.state.isLoggedIn and Config.DoHealthDamage then
            health = GetEntityHealth(cache.ped)

            if temp < Config.MinTemp then
                if Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true)
                end
                if Config.DoHealthPainSound then
                    PlayPain(cache.ped, 9, 1, true, true)
                end
                SetEntityHealth(cache.ped, health - Config.RemoveHealth)
            elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then
                Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed")
            end

            if temp > Config.MaxTemp then
                if Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true)
                end
                if Config.DoHealthPainSound then
                    PlayPain(cache.ped, 9, 1, true, true)
                end
                SetEntityHealth(cache.ped, health - Config.RemoveHealth)
            elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then
                Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed")
            end

            if cleanliness ~= nil and cleanliness < Config.MinCleanliness then
                if Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true)
                end
                if Config.DoHealthPainSound then
                    PlayPain(cache.ped, 9, 1, true, true)
                end
                SetEntityHealth(cache.ped, health - Config.RemoveHealth)
            elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then
                Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed")
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Health damage from hunger and thirst
--
-- ═══ What was wrong, in one line ═══
--
--   The old loop did SetEntityHealth(ped, health - Config.NeedsDamageAmount) with that
--   value at 1 -- and RDR3's health runs **0 to 600**, not 0 to 100. One point every
--   fifteen seconds is a quarter of a percent a minute: a character who stopped eating
--   took over two hours to die, and for the first ninety minutes of it nothing visible
--   happened at all. Which is exactly how it was reported -- hunger does nothing.
--
--   ★ So the number the admin sets is on the **0-100 scale** they and the player both
--     read, and the conversion to the engine's scale happens here, at the single point
--     where it meets the engine. Nobody has to know about 600 anywhere else.
--
-- ⚠️ The warning is not sent on every damaging tick. At a twenty-second interval that
--   would be three toasts a minute for as long as someone is hungry, which does not
--   teach urgency -- it teaches people to ignore the toast that matters.
-- ════════════════════════════════════════════════════════════════════════════

--- RDR3's health scale. The HUD divides by this over 100 to draw its circles.
local RDR_HEALTH_MAX = 600

--- Damaging ticks between one warning and the next.
local NOTIFY_EVERY = 4

--- The warning in the player's language (`key` is a dictionary key).
local function needWarning(key, icon, colour)
    WHudLocale.notify(key, colour, icon, 5000)
end

--
-- ⚠️ It counts seconds rather than sleeping the interval -- for the same reason the decay
--   loop in server/metabolism.lua does. Sleeping the interval means the sleep already
--   under way is the *old* one, so a change made in the panel appears to do nothing until
--   the previous cycle finishes.
CreateThread(function()
    local hungerTicks, thirstTicks = 0, 0
    local elapsed = 0

    while true do
        Wait(1000)

        -- ★ Read every pass: these are the admin's numbers now (server/admin.lua), and a
        --   slider moved in the panel must take effect on the next tick, not the next
        --   restart.
        local dmg = WHudSrv and WHudSrv.damage or nil

        local seconds = dmg and tonumber(dmg.interval)
            or ((Config.NeedsDamageInterval or 15000) / 1000)
        if not seconds or seconds < 1 then seconds = 1 end

        elapsed = elapsed + 1
        if elapsed < seconds then goto continue end
        elapsed = 0

        local enabled = dmg and dmg.enabled or (dmg == nil and Config.HungerThirstDamage)

        if enabled and LocalPlayer.state.isLoggedIn then
            local ped = cache.ped

            local hungerAt = dmg and tonumber(dmg.hungerAt) or (Config.HungerDamageThreshold or 5)
            local thirstAt = dmg and tonumber(dmg.thirstAt) or (Config.ThirstDamageThreshold or 5)
            local amount   = dmg and tonumber(dmg.amount) or (Config.NeedsDamageAmount or 1)

            -- The conversion, and the only place it happens.
            local bite = math.max(1, math.floor(amount * (RDR_HEALTH_MAX / 100) + 0.5))

            -- ⚠️ Without the licence to kill the bar stops just short of empty rather than
            --   at it: a starving player is left on their last legs, not face down.
            local floorHp = (dmg and dmg.canKill == false)
                and math.floor(RDR_HEALTH_MAX * 0.05) or 0

            --- One bite out of the health bar. Returns whether anything was actually taken,
            --- so a player already at the floor stops collecting warnings about it.
            local function bleed()
                local health = GetEntityHealth(ped)
                if health <= floorHp then return false end

                SetEntityHealth(ped, math.max(floorHp, health - bite))
                return true
            end

            if (tonumber(hunger) or 100) <= hungerAt then
                if bleed() then
                    hungerTicks = hungerTicks + 1
                    if hungerTicks % NOTIFY_EVERY == 1 then
                        needWarning('notify.hungry', 'mp_anim_eat', WHudLocale.PAPER)
                    end
                end
            else
                hungerTicks = 0
            end

            if (tonumber(thirst) or 100) <= thirstAt then
                if bleed() then
                    thirstTicks = thirstTicks + 1
                    if thirstTicks % NOTIFY_EVERY == 1 then
                        needWarning('notify.thirsty', 'awards_set_g_013', WHudLocale.PAPER)
                    end
                end
            else
                thirstTicks = 0
            end
        end

        ::continue::
    end
end)


CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn and Config.EnableMail then
            w.callback.triggerServer('w_hud:server:getTelegramsAmount', function(amount)
                youhavemail = (amount or 0) > 0
            end)
        end
        Wait(Config.TelegramCheck)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            local cinematic = Citizen.InvokeNative(0xBF7C780731AADBF8, true)
            -- local isBathingActive = exports['rsg-bathing']:IsBathingActive()
            if cinematic == true then
                incinematic = true
            else
                incinematic = false
            end
            -- if isBathingActive then
            --     inBathing = true
            -- else
            --     inBathing = false
            -- end
        end

        Wait(500)
    end
end)



function getCompassDirection(compassAngle)
    if not compassAngle then return 'N' end
    local compassDirection = 'string'

    if compassAngle >= 40 and compassAngle < 80 then
        compassDirection = "NE"
    elseif compassAngle >= 80 and compassAngle < 135 then
        compassDirection = "E"
    elseif compassAngle >= 135 and compassAngle < 200 then
        compassDirection = "SE"
    elseif compassAngle >= 200 and compassAngle < 260 then
        compassDirection = "SW"
    elseif compassAngle >= 260 and compassAngle < 280 then
        compassDirection = "S"
    elseif compassAngle >= 280 and compassAngle < 315 then
        compassDirection = "W"
    elseif compassAngle >= 315 and compassAngle < 360 then
        compassDirection = "NW"
    else
        compassDirection = "N"
    end

    return compassAngle
end

-- ════════════════════════════════════════════════════════════════════════════
-- /mapdebug -- why did the minimap disappear?
--
-- ★ Three parties fight over the minimap in this resource alone:
--     thread.lua        SetMinimapType every 500ms per the config
--     ammo.lua          per-component hide every frame + DisplayRadar(true)
--     wheel.lua         DisplayRadar when the wheel opens and closes
--   And vorp_core adds DisplayRadar(false) on respawn. Guessing gets you nowhere.
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('mapdebug', function()
    local function line(label, ok, detail)
        print(('%s %-34s %s'):format(ok and '^2[v]^7' or '^1[x]^7', label, detail or ''))
    end

    print('^3== w_hud - MINIMAP DIAGNOSTIC ===========================^0')

    -- 1) the settings
    line('Config.OnFootMinimap', Config.OnFootMinimap == true, tostring(Config.OnFootMinimap))
    line('Config.OnFootCompass', true, tostring(Config.OnFootCompass))
    line('Config.MounttMinimap', true, tostring(Config.MounttMinimap))
    line('showUI', showUI ~= false, tostring(showUI))
    line('hideStement (hidden flag)', hideStement ~= true, tostring(hideStement))

    -- 2) do these natives even exist on this build?
    --    a missing name is nil, and calling it throws, killing the thread silently.
    line('SetMinimapType exists', type(rawget(_G, 'SetMinimapType')) == 'function')
    line('DisplayRadar exists', type(rawget(_G, 'DisplayRadar')) == 'function')
    line('SetRadarConfigType exists', type(rawget(_G, 'SetRadarConfigType')) == 'function')

    -- 3) is the minimap thread alive? (the counter rises every cycle)
    line('minimap thread alive', (mapTicks or 0) > 0, ('ticks=%s'):format(tostring(mapTicks)))

    -- 4) force it directly -- if it appears now, something else is writing over us
    print('^7forcing minimap on for 5 seconds...^0')

    CreateThread(function()
        local deadline = GetGameTimer() + 5000

        while GetGameTimer() < deadline do
            pcall(function()
                w.setRadarVisible(true)
                SetMinimapType(1)
            end)
            Wait(0)
        end

        print('^7force ended. Did the map appear during those 5s?^0')
        print('^7  yes -> something overwrites us; tell me and I trace who.^0')
        print('^7  no  -> the natives do not control it on this build.^0')
        print('^3=========================================================^0')
    end)
end, false)
