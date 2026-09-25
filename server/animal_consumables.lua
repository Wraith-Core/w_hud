WHudAnimalUse = {}

function WHudAnimalUse.validate(src, netId, item)
    if type(netId) ~= 'number' or netId < 1 then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local me = GetPlayerPed(src)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then return nil end
    -- ! No server health read of the animal: this build answers 0 for a live ped a client created
    --   (w_stables' watchdogs note the same), which refused every animal. A dead one cannot run
    --   the eating scenario the client waits on, and the client never offers a dead or fleeing one.
    if not me or me == 0 then return nil end
    if GetEntityRoutingBucket(entity) ~= GetPlayerRoutingBucket(src) then return nil end
    if #(GetEntityCoords(me) - GetEntityCoords(entity)) > Config.AnimalCare.Distance + 0.5 then return nil end
    local profile = WHudAnimalProfile(GetEntityModel(entity), item)
    if not profile then return nil end
    -- Owned stable horses always go through their owner's persisted stable state.
    local state = Entity(entity).state
    if state.w_stables or state.horseUUID then return nil end
    if state.w_pets then
        if GetResourceState('w_pets') ~= 'started' or state.w_pets.owner ~= src then return nil end
        local owned = exports.w_pets:GetActivePet(src)
        if not owned or owned.netId ~= netId or owned.id ~= state.w_pets.id then return nil end
    end
    local previous = state.w_hudAnimalNeeds
    if previous and GetGameTimer() - (previous.lastFeed or 0) < Config.AnimalCare.Cooldown then return nil end
    return entity
end

function WHudAnimalUse.apply(src, netId, item)
    local entity = WHudAnimalUse.validate(src, netId, item)
    if not entity then return false end
    local state = Entity(entity).state
    local previous = state.w_hudAnimalNeeds or {}
    local water = Config.AnimalFood[item] == 'water'
    if state.w_pets then return exports.w_pets:ApplyFood(src, netId, water) == true end
    state:set('w_hudAnimalNeeds', {
        hunger = math.min(100, (previous.hunger or 50) + (water and 0 or 25)),
        thirst = math.min(100, (previous.thirst or 50) + (water and 35 or 0)),
        lastFeed = GetGameTimer(),
    }, true)
    return true
end
