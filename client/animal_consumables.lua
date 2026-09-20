WHudAnimalClient = {}
local activeAnimal

function WHudAnimalClient.cleanup()
    if activeAnimal and DoesEntityExist(activeAnimal) then ClearPedTasks(activeAnimal) end
    activeAnimal = nil
end

function WHudAnimalClient.choices(item)
    local nearby, me = {}, cache.ped
    local origin = GetEntityCoords(me)
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= me and DoesEntityExist(ped) and not IsPedHuman(ped) and not IsEntityDead(ped)
            and NetworkGetEntityIsNetworked(ped) and not IsPedInCombat(ped, me) and not IsPedFleeing(ped) then
            local distance = #(origin - GetEntityCoords(ped))
            if distance <= Config.AnimalCare.Distance then
                local stable = Entity(ped).state.w_stables
                local profile = WHudAnimalProfile(GetEntityModel(ped), item)
                local kind, label
                if stable then
                    if stable.owner == GetPlayerServerId(PlayerId()) and Config.HorseItems[item] then
                        kind, label = 'horse', stable.name or locale('needs.targetHorse')
                    end
                elseif Entity(ped).state.w_pets and profile then
                    local owned = Entity(ped).state.w_pets
                    if owned.owner == GetPlayerServerId(PlayerId()) then kind, label = 'animal', owned.name end
                elseif not Entity(ped).state.horseUUID and profile then
                    kind, label = 'animal', locale('animal.' .. profile.family)
                end
                if kind then
                    local id = NetworkGetNetworkIdFromEntity(ped)
                    nearby[#nearby + 1] = { value = kind .. ':' .. id,
                        label = ('%s (%.1f m)'):format(label, distance), distance = distance }
                end
            end
        end
    end
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    local options = { { value = 'player', label = locale('needs.targetPlayer') } }
    for i = 1, math.min(4, #nearby) do options[#options + 1] = nearby[i] end
    return options
end

function WHudAnimalClient.play(ped, item, actionWait, makeProp)
    local profile = WHudAnimalProfile(GetEntityModel(ped), item)
    if not profile or IsPedInCombat(ped, cache.ped) or IsPedFleeing(ped) then return false end
    local deadline = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(ped)
        actionWait(50)
    end
    if not NetworkHasControlOfEntity(ped) then return false end
    local water = Config.AnimalFood[item] == 'water'
    local scenario = water and profile.drink or profile.eat
    if not scenario then return false end
    local asset = Config.ItemPresentation[item]
    local prop = makeProp(water and 'p_bowl04x' or (asset and asset.model))
    if not prop then return false end
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.65, 0.0)
    SetEntityCoords(prop, pos.x, pos.y, pos.z, false, false, false, false)
    PlaceObjectOnGroundProperly(prop, true)
    activeAnimal = ped
    local hash = joaat(scenario)
    Citizen.InvokeNative(0x524B54361229154F, ped, hash, -1, true, 0, GetEntityHeading(ped), false)
    Citizen.InvokeNative(0x524B54361229154F, cache.ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, 0, 0.0, false)
    local start = GetGameTimer()
    while GetGameTimer() - start < 2500 do
        if Citizen.InvokeNative(0x34D6AC1157C8226C, ped, hash) then break end
        actionWait(100)
    end
    if not Citizen.InvokeNative(0x34D6AC1157C8226C, ped, hash) then return false end
    start = GetGameTimer()
    while GetGameTimer() - start < Config.AnimalCare.Duration do
        if not DoesEntityExist(ped) or IsEntityDead(ped) or
            #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) > Config.AnimalCare.Distance + 0.5 or
            not Citizen.InvokeNative(0x34D6AC1157C8226C, ped, hash) then return false end
        actionWait(100)
    end
    return true
end

function WHudAnimalClient.apply(netId, item)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local ped = NetToPed(netId)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end
    local water = Config.AnimalFood[item] == 'water'
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, math.min(100, GetAttributeCoreValue(ped, 1) + 20))
    if not water then
        local maximum = GetEntityMaxHealth(ped)
        SetEntityHealth(ped, math.min(maximum, GetEntityHealth(ped) + math.floor(maximum * 0.1)), 0)
        Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, math.min(100, GetAttributeCoreValue(ped, 0) + 15))
    end
end
