-- Companion visibility follows the HUD master visibility. No pet means no companion cores.
local function hasConfirmedCompanion()
    if GetResourceState('w_pets')~='started' then return false end
    local ok,pet,record=pcall(function()return exports.w_pets:GetPet()end)
    return ok and pet and pet~=0 and type(record)=='table' and record.id and record.netId
        and DoesEntityExist(pet) and NetworkGetNetworkIdFromEntity(pet)==record.netId
end
AddEventHandler('w_hud:companion', function(data)
    -- GetPet remains the existing client export. A local entity awaiting server approval has no netId.
    SendNUIMessage({action='companion',pet=type(data)=='table' and hasConfirmedCompanion() and data or false})
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource=='w_pets' then SendNUIMessage({action='companion',pet=false}) end
end)
AddEventHandler('WCore:Client:OnPlayerUnload',function()SendNUIMessage({action='companion',pet=false})end)
