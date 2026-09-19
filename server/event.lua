-- NOTE: hunger/thirst logic and the decay loop moved wholesale to server/metabolism.lua
-- (a framework-agnostic metabolism built on w_lib). Only generic wiring stays here.

RegisterServerEvent('setWeather', function(weatherType)
    TriggerClientEvent('hud:client:UpdateWeather', -1, weatherType)
end)
