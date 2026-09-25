-- Behavioral corrections applied after the generated catalog.
-- Nutrition remains the server's RP balance, not a claim about Rockstar values.
Config.Use = { Timeout = 30000, CancelControl = 0x156F7119 }

-- Native Dead Eye is optional (Config.Focus). A focus item works either way: it keeps the
-- stamina it was catalogued with, and only its Dead Eye part waits for the integration.
-- ! These used to be refused outright while Focus is off ('needs.focusUnavailable'), so the
--   apothecary sold snake oil and valerian root that could never be used.
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
        entry.focus, entry.focusOptional = amount, true
    end
end

-- Tobacco steadies the nerves: a small lift of the stamina core (nicotine is a stimulant, not
-- an energy tonic - no buff, no ring), plus Dead Eye when Config.Focus is on. Without the lift
-- tobacco was a pure loss with Focus off: its only effect was the health-core penalty.
for item, amount in pairs({ consumable_cigar = 40, rdr_cigarette = 15,
    consumable_chewing_tobacco = 30, consumable_herb_indian_tobacco = 35, rdr_tobacco_pipe = 45 }) do
    local entry = Config.Consumables[item]
    entry.stamina, entry.focus, entry.focusOptional = math.floor(amount / 2), amount, true
    entry.buff = nil
end

-- The stamina ring (the bar you sprint on) is the ped's stamina, apart from the core: food only
-- feeds the cores, a tonic also refills the bar, as in the game. outerStamina = percent of the
-- ped's maximum, added on top of what is left (client/consumables.lua applyCores).
for item, percent in pairs({
    consumable_tonic = 50, consumable_potent_tonic = 100, consumable_special_tonic_crafted = 100,
    consumable_snake_oil = 35, consumable_potent_snake_oil = 70, consumable_special_snake_oil_crafted = 100,
    consumable_restorative = 50, consumable_potent_restorative = 100, consumable_special_restorative_crafted = 100,
    consumable_ginseng_elixier = 40, consumable_valerian_root = 25, consumable_cocaine_chewing_gum = 100,
    consumable_coffee = 25,
}) do
    local entry = Config.Consumables[item]
    if entry then entry.outerStamina = percent end
end

-- Coffee is the energy drink of the period (NEEDS.md lists it as the source of the energy buff).
Config.Consumables.consumable_coffee.buff = { type = 'energy', amount = 20 }

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

-- Dry ingredients are used by recipes rather than eaten as prepared food: ground coffee is
-- brewed at the campfire (w_crafting data/campfire.lua). Seasoning stays a herb like oregano or
-- thyme: no recipe takes it, so blocking it left the stores selling an item nobody could use.
Config.Consumables.consumable_coffee_gnds_reg = { kind = 'ingredient', blocked = 'needs.cookIngredient' }

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
