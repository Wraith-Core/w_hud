RegisterNetEvent("HideAllUI", function()
    showUI = not showUI
end)

RegisterNetEvent('hud:client:UpdateWeather', function(weatherType)
    local weatherName = weatherNames[weatherType] or "SUNNY"
    currentWeather = weatherName
    SendNUIMessage({
        action = 'updateWeather',
        weatherName = currentWeather
    })
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst, newCleanliness)
    local cleanstats = Citizen.InvokeNative(0x147149F2E909323C, cache.ped, 16, Citizen.ResultAsInteger())
    hunger = newHunger
    thirst = newThirst
    cleanliness = newCleanliness - cleanstats
end)

RegisterNetEvent('hud:client:UpdateHunger', function(newHunger)
    if newHunger < 0 then newHunger = 0 end
    if newHunger > 100 then newHunger = 100 end
    hunger = newHunger
    -- persisted through the w_hud metabolism (all frameworks)
    TriggerServerEvent('w_hud:server:setNeed', 'hunger', newHunger)
end)

RegisterNetEvent('hud:client:UpdateThirst', function(newThirst)
    if newThirst < 0 then newThirst = 0 end
    if newThirst > 100 then newThirst = 100 end
    thirst = newThirst
    -- persisted through the w_hud metabolism (all frameworks)
    TriggerServerEvent('w_hud:server:setNeed', 'thirst', newThirst)
end)

RegisterNetEvent('hud:client:showui', function()
    show = true
end)

RegisterNetEvent('hud:client:Hideui', function()
    show = false
end)


RegisterNetEvent('w_hud:client:updateMoney', function(playercash, playergold, playerbank, playerdirty)
    if not playercash then playercash = 0.0 end
    if type(playercash) ~= "number" then playercash = tonumber(playercash) or 0.0 end

    if not playergold then playergold = 0.0 end
    if type(playergold) ~= "number" then playergold = tonumber(playergold) or 0.0 end

    cash = playercash
    gold = playergold

    -- Assigned only when the server states them: an older server build sends two
    -- arguments, and reading the missing pair as zero would blank a real balance.
    if playerbank ~= nil then bank = tonumber(playerbank) or 0.0 end
    if playerdirty ~= nil then dirty = tonumber(playerdirty) or 0.0 end
end)

-- ★ The money events (VORP and RSG) moved to client/framework.lua along with
--   everything else framework-facing. They used to be scattered between this
--   file and client/metabolism.lua, so anyone asking "what does the HUD read
--   from the framework?" had to read two files and still got no answer.
RegisterNetEvent("hud:client:hideUiWithHoutStement", function() hideStement = true end)
RegisterNetEvent("hud:client:showUiWithHoutStement", function() hideStement = false end)
