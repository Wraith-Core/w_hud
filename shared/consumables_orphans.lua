-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · shared/consumables_orphans.lua
-- The consumables the satchel sold but nothing could use
--
-- ═══ Where these come from (2026-09-18) ═══
--
--   The live `items` table holds 4290 rows, 4077 of them marked usable. A row is only
--   usable in play when some server resource registers it; w_hud registered its curated
--   dozen and the 170 rows ported from bln_hud, every other script registers its own, and
--   what was left -- food, drink, spirits, tonics, tobacco a player can buy or hold and
--   then "use" for nothing -- is this file. Every name was checked against the table, the
--   registering loops of every other resource, and the w_hud field scale; raw meat, seeds,
--   herbs and horse-only items are NOT here (the cooking, farming and stable scripts own
--   them), and the rows whose name and label contradict each other (consumable_sugarcube,
--   consumable_carrot, consumable_moonshine) wait for the row to be fixed first.
--
--   Same rule as consumables_ported.lua: Config.Consumables[k] is filled only where it is
--   still empty, so the curated and the ported entries always win over these.
--
-- ⚠️ 'bandage' is here as a self-use medical item (86 held, nothing registered it). gw-medic
--    consumes the same item from the MEDIC's bag when treating a patient; that path does not
--    go through registerUsableItem, so both coexist -- but a player may now bandage himself.
--    Delete that one entry if the medic job should stay the only way.
-- ════════════════════════════════════════════════════════════════════════════

local function addMissing(target, rows)
    for key, row in pairs(rows) do
        if target[key] == nil then target[key] = row end
    end
end

local Orphans = {
    ['a_milk'] = { -- ranch milk, same product as 'milk'
        kind = 'drink',
        hunger = 10, thirst = 25,
        anim = 'bottle_small', prop = 'p_water01x',
    },
    ['alcohol'] = { -- generic liquor per desc
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        giveBack = { item = 'alcoholbottle', amount = 1 },
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['balm_healing'] = { -- healing balm per desc
        kind = 'medical',
        innerHealth = 10, outerHealth = 60,
        heal = true,
        anim = 'bandage',
    },
    ['banana'] = { -- fruit
        kind = 'food',
        hunger = 15, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['bandage'] = { -- plain medical bandage, 86 held, nothing registers it
        kind = 'medical',
        outerHealth = 60,
        heal = true,
        anim = 'bandage',
    },
    ['Black_Berry'] = { -- edible wild berry
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['blackberry'] = { -- edible berry
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['blackberryale'] = { -- blackberry beer per desc
        kind = 'alcohol',
        thirst = 30, stamina = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle_small', prop = 'p_bottlebeer01a',
    },
    ['blackmulberry'] = { -- edible berry per desc
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['blueberry'] = { -- edible berry per desc
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['bread'] = { -- desc says fresh bread that fills hunger
        kind = 'food',
        hunger = 25, thirst = -5,
        anim = 'bite', prop = 'p_bread06x',
    },
    ['carrots'] = { -- root vegetable per desc, edible raw
        kind = 'food',
        hunger = 10, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['Ceai'] = { -- tea per label/desc
        kind = 'drink',
        hunger = 5, thirst = 30, stamina = 10,
        anim = 'mug', prop = 'p_teacup01x',
    },
    ['champagne'] = { -- champagne
        kind = 'alcohol',
        thirst = 25, stamina = 10,
        fx = 'PlayerDrunk01', fxTime = 1,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['cheese'] = { -- cheese, edible
        kind = 'food',
        hunger = 20,
        anim = 'bite', prop = 's_bit_cheesewedge1x',
    },
    ['chicken_stew'] = { -- cooked stew
        kind = 'food',
        hunger = 40, thirst = 10, stamina = 10,
        innerHealth = 10,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['cocaine_soaked_bandage'] = { -- strong bandage per label/desc
        kind = 'medical',
        stamina = 30,
        outerHealth = 120,
        heal = true,
        anim = 'bandage',
    },
    ['coffee'] = { -- hot coffee per desc
        kind = 'drink',
        thirst = 30, stamina = 20,
        buff = { type = 'energy', amount = 20 },
        anim = 'mug', prop = 'p_mugcoffee01x',
    },
    ['consumable_alcohol_cranberry_sparkler'] = { -- sparkling cranberry cocktail
        kind = 'alcohol',
        hunger = 5, thirst = 30, stamina = 10,
        fx = 'PlayerDrunk01', fxTime = 1,
        anim = 'glass', prop = 'p_glass01x',
    },
    ['consumable_apricots_can'] = { -- canned apricots
        kind = 'food',
        hunger = 25, thirst = 10,
        anim = 'can', prop = 's_canrigbeef01x',
    },
    ['consumable_baked_beans_can'] = { -- canned baked beans
        kind = 'food',
        hunger = 30, thirst = 5,
        anim = 'can', prop = 's_canrigbeef01x',
    },
    ['consumable_blueberrypie'] = { -- pie
        kind = 'food',
        hunger = 35, thirst = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_bluegil'] = { -- dried fish
        kind = 'food',
        hunger = 20, thirst = -5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_bread_roll'] = { -- bread roll (same scale as ported bread6)
        kind = 'food',
        hunger = 20,
        anim = 'bite', prop = 'p_bread06x',
    },
    ['consumable_carib_rum'] = { -- rum
        kind = 'alcohol',
        thirst = 25, stamina = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['consumable_chocolate_bar'] = { -- chocolate bar
        kind = 'food',
        hunger = 15, stamina = 10,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_chocolatecake'] = { -- cake
        kind = 'food',
        hunger = 30,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_chocolatecoffee'] = { -- chocolate coffee drink
        kind = 'drink',
        hunger = 10, thirst = 30, stamina = 15,
        anim = 'mug', prop = 'p_mugcoffee01x',
    },
    ['consumable_cigar'] = { -- cigar with no owner (rakan_smoke owns 'cigar' only)
        kind = 'drug',
        stamina = 10,
        buff = { type = 'energy', amount = 10 },
        anim = 'cigar', prop = 'p_cigarette01x',
    },
    ['consumable_cupcake'] = { -- cupcake (ported cupcake_* siblings are food)
        kind = 'food',
        hunger = 30, thirst = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_cyprus_brandy'] = { -- brandy
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['consumable_fruitsalad'] = { -- fruit salad
        kind = 'food',
        hunger = 25, thirst = 15,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_game'] = { -- dried seasoned jerky per desc (not raw)
        kind = 'food',
        hunger = 25, thirst = -5, stamina = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_grapejelly'] = { -- grape jelly
        kind = 'food',
        hunger = 15, thirst = 5,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_herb_evergreen_huckleberry'] = { -- ripe berries per desc
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_herb_wintergreen_berry'] = { -- edible berries per desc
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_londry_gin'] = { -- gin
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['consumable_meat_big_game_cooked'] = { -- cooked game meat
        kind = 'food',
        hunger = 40, thirst = -5, stamina = 10,
        innerHealth = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_meat_greavy'] = { -- meat stew
        kind = 'food',
        hunger = 40, thirst = 10,
        innerHealth = 10,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['consumable_meat_succulent_fish_cooked'] = { -- cooked fish
        kind = 'food',
        hunger = 35,
        innerHealth = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_moonshine_alaskan'] = { -- moonshine
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_moonshine_american'] = { -- moonshine
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_moonshine_blackberry'] = { -- flavoured moonshine
        kind = 'alcohol',
        hunger = 5, thirst = 25, stamina = 10,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_moonshine_raspberry'] = { -- flavoured moonshine
        kind = 'alcohol',
        hunger = 5, thirst = 25, stamina = 10,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_oldtom_gin'] = { -- gin
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['consumable_peach'] = { -- fresh fruit
        kind = 'food',
        hunger = 15, thirst = 10,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_peachcobbler'] = { -- cobbler (ported cobbler_strawberry is 47/20; kept a bit lower)
        kind = 'food',
        hunger = 35, thirst = 10,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_pear'] = { -- fresh fruit
        kind = 'food',
        hunger = 15, thirst = 10,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_peppermint'] = { -- mint candy per desc
        kind = 'food',
        hunger = 5, stamina = 10,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['consumable_pineapples_can'] = { -- canned pineapple
        kind = 'food',
        hunger = 25, thirst = 15,
        anim = 'can', prop = 's_canrigbeef01x',
    },
    ['consumable_plymouth_gin'] = { -- gin
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['consumable_poison_tonic'] = { -- label سم الثعبان (snake venom)
        kind = 'poison',
        thirst = 5,
        outerHealth = -30,
        poison = 60,
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['consumable_potent_snake_oil'] = { -- RDR potent snake oil (stamina tonic)
        kind = 'medical',
        thirst = 5, stamina = 80,
        goldStaminaInner = 1, goldStaminaOuter = 1,
        buff = { type = 'energy', amount = 50 },
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['consumable_potent_tonic'] = { -- RDR potent tonic (gilds health+stamina)
        kind = 'medical',
        thirst = 10, stamina = 60,
        innerHealth = 30, outerHealth = 100,
        goldHealthOuter = 1, goldStaminaOuter = 1,
        buff = { type = 'energy', amount = 40 },
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['consumable_raspberryjelly'] = { -- Jam in a jar, same family as consumable_peachjelly already in the port
        kind = 'food',
        hunger = 30, thirst = 15,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['consumable_steakpie'] = { -- Beef pie, a full meal like the other consumable_pie_* rows.
        kind = 'food',
        hunger = 40, thirst = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['consumable_sweet_corn_can'] = { -- Canned sweet corn, duplicate of the canned_corn row.
        kind = 'food',
        hunger = 45, thirst = 10,
        anim = 'can', prop = 's_canrigcorn01x',
    },
    ['consumable_trout'] = { -- Desc says cooked and seasoned trout, ready to eat.
        kind = 'food',
        hunger = 40, thirst = 5,
        anim = 'bite', prop = 'p_cs_steakslice01x',
    },
    ['consumable_water'] = { -- bottle of drinking water
        kind = 'drink',
        thirst = 40,
        giveBack = { item = 'empty_bottle', amount = 1 },
        anim = 'bottle_small', prop = 'p_water01x',
    },
    ['crabbutter'] = { -- Crab butter spread, a light bite.
        kind = 'food',
        hunger = 20,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['Creekplum'] = { -- small juicy plum per desc
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['Evergreen_Huckleberry'] = { -- edible berry per desc
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['friedtater'] = { -- Fried potatoes, duplicate of the ported consumable_friedtater row.
        kind = 'food',
        hunger = 37, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['ginsengtea'] = { -- Herbal tea, same scale as consumable_tea_* rows.
        kind = 'drink',
        thirst = 35, stamina = 10,
        anim = 'mug', prop = 'p_teacup01x',
    },
    ['golden_tonic'] = { -- 'Golden' tonic: the gilding tonic tier like herbal_tonic.
        kind = 'medical',
        thirst = 15,
        innerHealth = 50, outerHealth = 150,
        goldHealthInner = 1, goldHealthOuter = 1,
        buff = { type = 'health', amount = 50 },
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['grape'] = { -- Fresh fruit, edible raw.
        kind = 'food',
        hunger = 10, thirst = 10,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['health_tonic'] = { -- Health tonic, below herbal_tonic tier.
        kind = 'medical',
        thirst = 15,
        innerHealth = 40, outerHealth = 120,
        buff = { type = 'health', amount = 40 },
        heal = true,
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['herbal_medicine'] = { -- Herbal medicine, a poison antidote / light heal.
        kind = 'medical',
        thirst = 10,
        innerHealth = 30, outerHealth = 60,
        heal = true,
        curesPoison = true,
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['herbmed'] = { -- Duplicate of herbal_medicine under another name.
        kind = 'medical',
        thirst = 10,
        innerHealth = 30, outerHealth = 60,
        heal = true,
        curesPoison = true,
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['heroin'] = { -- Hard drug, hallucination fx like the marijuana rows.
        kind = 'drug',
        stamina = 60,
        outerHealth = 100,
        fx = 'playerdrugshalluc01', fxTime = 2,
        anim = 'syringe', prop = 's_inv_syringe01x',
    },
    ['honey'] = { -- honey, edible sweet
        kind = 'food',
        hunger = 15, thirst = 5, stamina = 10,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['honey_gk'] = { -- Honey in a jar.
        kind = 'food',
        hunger = 20, thirst = 10, stamina = 10,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['iguanabits'] = { -- Cooked iguana pieces.
        kind = 'food',
        hunger = 30,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['join'] = { -- Hashish cigarette (typo of joint); rakan_smoke has 'joint' not 'join',
        kind = 'drug',
        stamina = 30,
        outerHealth = 100,
        fx = 'playerdrugshalluc01', fxTime = 1,
        anim = 'cigarette', prop = 'p_cigarette01x',
    },
    ['laudanum'] = { -- Painkiller/sedative, painkiller tier with a mild blur.
        kind = 'drug',
        thirst = 5,
        innerHealth = 20, outerHealth = 100,
        buff = { type = 'health', amount = 30 },
        fx = 'PlayerDrunk01', fxTime = 1,
        anim = 'tonic', prop = 'p_bottlemedicine03x',
    },
    ['milk'] = { -- dairy drink per desc
        kind = 'drink',
        hunger = 10, thirst = 30,
        innerHealth = 5,
        anim = 'bottle_small', prop = 'p_water01x',
    },
    ['moonshine'] = { -- strong illegal liquor per desc
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        innerHealth = 10,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['moonshine_blueflame'] = { -- Blue-flame moonshine, top-proof; leftover of a removed moonshiner scri
        kind = 'alcohol',
        thirst = 25, stamina = 20,
        fx = 'PlayerDrunkStrong', fxTime = 3,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['moonshine_original'] = { -- Plain moonshine.
        kind = 'alcohol',
        thirst = 25, stamina = 15,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['moonshine_red'] = { -- Flavoured moonshine.
        kind = 'alcohol',
        thirst = 25, stamina = 15,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['moonshine_yellow'] = { -- Flavoured moonshine.
        kind = 'alcohol',
        thirst = 25, stamina = 15,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['morphine'] = { -- Same substance as the curated morphine_shot.
        kind = 'drug',
        stamina = 45,
        innerHealth = 40, outerHealth = 250,
        buff = { type = 'health', amount = 50 },
        heal = true,
        anim = 'syringe', prop = 's_inv_syringe01x',
    },
    ['mulberry'] = { -- Berries, edible raw.
        kind = 'food',
        hunger = 10, thirst = 10,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['peacepipe'] = { -- Tobacco pipe; w_hud has no tobacco kind, drug with pipe anim is the cl
        kind = 'drug',
        stamina = 15,
        anim = 'pipe',
    },
    ['pipepeace'] = { -- Peace pipe, tobacco; not owned by rakan_smoke.
        kind = 'drug',
        stamina = 15,
        anim = 'pipe',
    },
    ['pipepeace2'] = { -- Peace pipe 2, tobacco; not owned by rakan_smoke.
        kind = 'drug',
        stamina = 15,
        anim = 'pipe',
    },
    ['potion_healing'] = { -- Custom healing tonic per its desc.
        kind = 'medical',
        thirst = 10,
        innerHealth = 40, outerHealth = 150,
        buff = { type = 'health', amount = 40 },
        heal = true,
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['raspberryale'] = { -- Fruit beer, beer tier like large_beer plus a light saloon blur.
        kind = 'alcohol',
        thirst = 35, stamina = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'glass', prop = 'p_beermugglass01x',
    },
    ['Red_Raspberry'] = { -- edible wild berry
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['shrimps'] = { -- Shrimp soup, a bowl meal like the ported stews.
        kind = 'food',
        hunger = 40, thirst = 15,
        anim = 'stew', prop = 'p_bowl04x_stew',
    },
    ['stamina_tonic'] = { -- Stamina tonic, same job as the curated tonic_bitters.
        kind = 'medical',
        thirst = 15, stamina = 70,
        innerHealth = 10,
        goldStaminaInner = 1, goldStaminaOuter = 1,
        buff = { type = 'energy', amount = 60 },
        anim = 'tonic', prop = 's_inv_tonic01x',
    },
    ['steak'] = { -- Cooked steak, a filling meal per its desc.
        kind = 'food',
        hunger = 45, thirst = -5, stamina = 10,
        innerHealth = 15, outerHealth = 20,
        buff = { type = 'vigor', amount = 40 },
        anim = 'bite', prop = 'p_cs_steakslice01x',
    },
    ['steakveg'] = { -- Steak with vegetables, duplicate of the ported consumable_steak_veg.
        kind = 'food',
        hunger = 42, thirst = 20,
        anim = 'stew', prop = 'p_stewplate01x',
    },
    ['tequila'] = { -- Bottle of spirits, gin/liquor tier.
        kind = 'alcohol',
        thirst = 25, stamina = 15,
        innerHealth = 20,
        giveBack = { item = 'empty_bottle', amount = 1 },
        fx = 'PlayerDrunk01', fxTime = 1,
        anim = 'bottle', prop = 's_inv_gin01x',
    },
    ['tropicalPunchMoonshine'] = { -- Ginseng moonshine, moonshine tier.
        kind = 'alcohol',
        thirst = 30, stamina = 20,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['vanillacake'] = { -- Vanilla cake, dessert.
        kind = 'food',
        hunger = 35, thirst = 5,
        anim = 'bite', prop = 'p_pie01x_slice',
    },
    ['vodka'] = { -- vodka per desc
        kind = 'alcohol',
        thirst = 20, stamina = 10,
        innerHealth = 10,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },
    ['White_Grapes'] = { -- edible grapes per desc
        kind = 'food',
        hunger = 10, thirst = 8,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
    ['wildCiderMoonshine'] = { -- Wild berry moonshine, moonshine tier.
        kind = 'alcohol',
        thirst = 30, stamina = 20,
        fx = 'PlayerDrunkStrong', fxTime = 2,
        anim = 'jar', prop = 'p_masonjar01x',
    },
    ['Wintergreen_Berry'] = { -- edible berry
        kind = 'food',
        hunger = 8, thirst = 5,
        anim = 'bite', prop = 'p_cs_candy01x',
    },
}

local OrphanHorse = {
    ['Boost_For_Horse'] = { kind = 'stamina', amount = 50, distance = 3.0 }, -- label تعزيز للحصان (horse boost)
    ['carrot'] = { kind = 'stamina', amount = 25, distance = 3.0 }, -- RDR carrot is horse feed; Wild_Carrot already goes to the ho
    ['consumable_apple'] = { kind = 'stamina', amount = 25, distance = 3.0 }, -- desc says لإطعام الحصان (to feed the horse)
    ['consumable_horse_ointment'] = { kind = 'feed', amount = 40, distance = 3.0 }, -- horse wound ointment per desc
    ['consumable_horse_reviver'] = { kind = 'feed', amount = 60, distance = 3.0 }, -- horse reviver per desc
    ['consumable_horsemeal'] = { kind = 'feed', amount = 40, distance = 3.0 }, -- horse meal per label
    ['consumable_potent_horse_medicine'] = { kind = 'feed', amount = 100, distance = 3.0 }, -- potent horse medicine per desc
    ['consumable_potent_horse_stimulant'] = { kind = 'stamina', amount = 100, distance = 3.0 }, -- potent horse stimulant per desc
    ['horsemeal'] = { kind = 'feed', amount = 40, distance = 3.0 }, -- Label says horse feed.
    ['horsestim'] = { kind = 'stamina', amount = 100, distance = 3.0 }, -- Horse stimulant.
    ['sugarcube'] = { kind = 'stamina', amount = 25, distance = 3.0 }, -- Sugar cube, standard horse treat in RDR.
    ['unique_brad_horsesugar'] = { kind = 'stamina', amount = 25, distance = 3.0 }, -- Label says horse sugar.
    ['Wild_Carrot'] = { kind = 'stamina', amount = 25, distance = 3.0 }, -- desc says طعام للحصان (horse food)
}

Config.Consumables = Config.Consumables or {}
Config.HorseItems  = Config.HorseItems or {}
addMissing(Config.Consumables, Orphans)
addMissing(Config.HorseItems, OrphanHorse)
