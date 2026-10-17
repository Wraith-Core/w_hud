-- NOTE: hunger/thirst logic and the decay loop moved wholesale to server/metabolism.lua
-- (a framework-agnostic metabolism built on w_lib). Only generic wiring stays here.

-- Audit (2026-10-18): a server-side event only. No script sends it from a client, and as a net event any player could
-- push a weather to every HUD on the server.
AddEventHandler('setWeather', function(weatherType)
    if type(weatherType) ~= 'string' or #weatherType > 32 then return end
    TriggerClientEvent('hud:client:UpdateWeather', -1, weatherType)
end)
