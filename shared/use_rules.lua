-- Behavioral corrections applied after the generated catalog.
-- Nutrition remains the server's RP balance, not a claim about Rockstar values.
Config.Use = { Timeout = 30000, CancelControl = 0x156F7119 }

-- Native Dead Eye is optional: do not convert focus items into stamina medicine.
Config.Focus = { Enabled = false }
local focus = {
    consumable_snake_oil = 50,
    consumable_potent_snake_oil = 75,
    consumable_special_snake_oil_crafted = 100,
    consumable_valerian_root = 50,
}
for item, amount in pairs(focus) do
    local entry = Config.Consumables[item]
    if entry then
        entry.stamina, entry.innerHealth, entry.buff = nil, nil, nil
        entry.goldStaminaInner, entry.goldStaminaOuter = nil, nil
        entry.focus = amount
    end
end

-- Tobacco restores focus when that integration is enabled; it is not an energy tonic.
for item, amount in pairs({ consumable_cigar = 40, rdr_cigarette = 15,
    consumable_chewing_tobacco = 30, consumable_herb_indian_tobacco = 35, rdr_tobacco_pipe = 45 }) do
    local entry = Config.Consumables[item]
    entry.stamina, entry.focus, entry.focusOptional = nil, amount, true
    entry.buff = nil
end

-- No hair-growth/pomade component integration exists in this server yet.
for _, item in ipairs({ 'consumable_hair_tonic', 'consumable_hair_grease' }) do
    Config.Consumables[item] = { kind = 'cosmetic', blocked = 'needs.cosmeticUnavailable' }
end

-- An antidote cures the poison state; it is not a health potion.
Config.Consumables.consumable_antidote = {
    kind = 'medical', curesPoison = true, anim = 'tonic', prop = 's_inv_antidote01x',
}

-- Keep the pipe; charge its tobacco only on completed use.
Config.Consumables.rdr_tobacco_pipe.consume = false
Config.Consumables.rdr_tobacco_pipe.requirement = { item = 'consumable_herb_indian_tobacco', count = 1 }
Config.Consumables.rdr_water_flask.scenario = 'WORLD_HUMAN_DRINK_FLASK'
Config.Consumables.rdr_champagne.scenario = 'WORLD_HUMAN_DRINK_CHAMPAGNE'
Config.Consumables.rdr_cigarette.scenario = 'WORLD_HUMAN_SMOKE'
Config.Consumables.consumable_moonshine.scenario = 'WORLD_HUMAN_DRINKING_MOONSHINE'

-- User-approved: both pack types contain 20 individual cigarettes.
for _, item in ipairs({ 'consumable_cigarette_box', 'consumable_cigarette_box_cheap' }) do
    Config.Consumables[item] = { kind = 'pack', anim = 'unpack', pack = { item = 'rdr_cigarette', count = 20 } }
end

-- Dry ingredients are used by recipes rather than eaten as prepared food.
Config.Consumables.consumable_coffee_gnds_reg = { kind = 'ingredient', blocked = 'needs.cookIngredient' }
Config.Consumables.rdr_seasoning = { kind = 'ingredient', blocked = 'needs.cookIngredient' }

-- Per-item props are also used when a native interaction is unavailable.
for item, entry in pairs(Config.Consumables) do
    local asset = Config.ItemPresentation[item]
    if asset and not entry.blocked and entry.anim ~= 'stew' and entry.anim ~= 'mug' then
        entry.prop = asset.model
    end
end

-- Shared food goes to the owned horse in reach, otherwise to the player.
-- w_stables persists these effects; HUD owns food registration and the interaction.
Config.HorseItems = {
    consumable_apple = { kind = 'feed', playerFallback = true, distance = 3.0, effect = { hunger = 25, stamina = 15, health = 10 } },
    consumable_carrot = { kind = 'feed', playerFallback = true, distance = 3.0, effect = { hunger = 25, stamina = 20, health = 10 } },
    consumable_celery = { kind = 'feed', playerFallback = true, distance = 3.0, effect = { hunger = 20, stamina = 15, health = 5 } },
    consumable_beets = { kind = 'feed', playerFallback = true, distance = 3.0, effect = { hunger = 25, stamina = 15, health = 10 } },
    consumable_corn = { kind = 'feed', playerFallback = true, distance = 3.0, effect = { hunger = 25, stamina = 15, health = 5 } },
    consumable_oat_cakes = { kind = 'feed', playerFallback = true, distance = 3.0, effect = { hunger = 35, stamina = 25, health = 10 } },
    consumable_herb_wild_carrots = { kind = 'feed', playerFallback = true, distance = 3.0, effect = { hunger = 20, stamina = 15, health = 5 } },
    rdr_water_flask = { kind = 'water', playerFallback = true, distance = 3.0, effect = { stamina = 20 } },
}
