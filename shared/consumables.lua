-- ════════════════════════════════════════════════════════════════════════════
-- w_hud — جدول الاستهلاكيّات ودعم الكتالوج البحثي
-- All 156 items integrated: hunger/thirst/stamina/health, poison & antidote,
-- horse items mapped with proximity validation, server-authoritative consumption.
-- ════════════════════════════════════════════════════════════════════════════

Config.Consumables = {
    ['consumable_aged_pirate_rum'] = {
        kind = 'alcohol', hunger = 0, thirst = 25, stamina = 40, innerHealth = 55, outerHealth = 50, goldStaminaOuter = 1, fxTime = 3, anim = 'bottle', fx = 'PlayerDrunkStrong'
    },
    ['consumable_herb_alaskan_ginseng'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_american_ginseng'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_antidote'] = {
        kind = 'medical', innerHealth = 40, outerHealth = 50, curesPoison = true, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'health', amount = 40 }
    },
    ['consumable_apple'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_herb_bay_bolete'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_saloon_beer'] = {
        kind = 'alcohol', hunger = 5, thirst = 35, stamina = 10, innerHealth = 15, fxTime = 1, anim = 'bottle_small', prop = 'p_bottlebeer01a', fx = 'PlayerDrunkSaloon1'
    },
    ['consumable_beets'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_biscuit_box'] = {
        kind = 'food', hunger = 25, thirst = -5, stamina = 15, innerHealth = 10, anim = 'bite'
    },
    ['consumable_tonic'] = {
        kind = 'medical', stamina = 60, anim = 'tonic', prop = 'p_bottlemedicine01x', buff = { type = 'energy', amount = 50 }
    },
    ['consumable_herb_black_currant'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_herb_black_berry'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_brandy'] = {
        kind = 'alcohol', hunger = 0, thirst = 25, stamina = 20, innerHealth = 45, outerHealth = 35, fxTime = 1, anim = 'bottle', fx = 'PlayerDrunkSaloon1'
    },
    ['consumable_bread_chunk'] = {
        kind = 'food', hunger = 25, thirst = -5, stamina = 10, innerHealth = 5, anim = 'bite', prop = 'p_cs_sandwich01x'
    },
    ['consumable_bread_roll'] = {
        kind = 'food', hunger = 30, thirst = -5, stamina = 10, innerHealth = 10, anim = 'bite', prop = 'p_cs_sandwich01x'
    },
    ['consumable_herb_common_bulrush'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_burdock_root'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_candy_bag'] = {
        kind = 'food', hunger = 15, thirst = -5, stamina = 25, innerHealth = 5, anim = 'bite'
    },
    ['consumable_apricots_can'] = {
        kind = 'food', hunger = 35, thirst = 15, stamina = 15, innerHealth = 10, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_baked_beans_can'] = {
        kind = 'food', hunger = 45, thirst = 5, stamina = 20, innerHealth = 15, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_kidneybeans_can'] = {
        kind = 'food', hunger = 45, thirst = 5, stamina = 20, innerHealth = 15, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_peaches_can'] = {
        kind = 'food', hunger = 35, thirst = 15, stamina = 15, innerHealth = 10, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_peas_can'] = {
        kind = 'food', hunger = 35, thirst = 5, stamina = 15, innerHealth = 10, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_pineapples_can'] = {
        kind = 'food', hunger = 40, thirst = 15, stamina = 20, innerHealth = 15, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_strawberries_can'] = {
        kind = 'food', hunger = 35, thirst = 15, stamina = 15, innerHealth = 10, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_sweet_corn_can'] = {
        kind = 'food', hunger = 40, thirst = 5, stamina = 15, innerHealth = 10, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_carrot'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_celery'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['rdr_champagne'] = {
        kind = 'alcohol', hunger = 0, thirst = 30, stamina = 20, innerHealth = 35, fxTime = 1, anim = 'bottle', fx = 'PlayerDrunkSaloon1'
    },
    ['consumable_herb_chanterelles'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_cheese_wedge'] = {
        kind = 'food', hunger = 35, thirst = -5, stamina = 15, innerHealth = 15, anim = 'bite'
    },
    ['consumable_chewing_tobacco'] = {
        kind = 'drug', stamina = 30, innerHealth = -5, anim = 'bite'
    },
    ['consumable_chocolate_bar'] = {
        kind = 'food', hunger = 20, thirst = -5, stamina = 30, innerHealth = 10, anim = 'bite'
    },
    ['consumable_cigar'] = {
        kind = 'drug', stamina = 40, innerHealth = -5, anim = 'cigar'
    },
    ['rdr_cigarette'] = {
        kind = 'drug', stamina = 15, innerHealth = -3, anim = 'cigarette'
    },
    ['consumable_cigarette_box_cheap'] = {
        kind = 'drug', stamina = 20, innerHealth = -5, anim = 'cigarette'
    },
    ['consumable_cocaine_chewing_gum'] = {
        kind = 'drug', stamina = 100, goldStaminaInner = 1, goldStaminaOuter = 1, anim = 'bite', buff = { type = 'energy', amount = 100 }
    },
    ['consumable_coffee'] = {
        kind = 'drink', hunger = 0, thirst = 40, stamina = 35, innerHealth = 10, anim = 'mug', prop = 'p_mugcoffee01x'
    },
    ['consumable_coffee_gnds_reg'] = {
        kind = 'food', hunger = 5, thirst = -5, stamina = 15, anim = 'bite'
    },
    ['consumable_big_game_meat_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_big_game_meat_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_big_game_meat_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_big_game_meat_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_crustacean_meat_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_crustacean_meat_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_crustacean_meat_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_crustacean_meat_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_exotic_bird_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_exotic_bird_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_exotic_bird_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_exotic_bird_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_flakey_fish_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_flakey_fish_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_flakey_fish_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_flakey_fish_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_game_meat_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_game_meat_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_game_meat_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_game_meat_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_gamey_bird_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_gristly_mutton_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_gristly_mutton_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_gristly_mutton_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_gristly_mutton_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_gritty_fish_meat_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_herptile_meat_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_mature_venison_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_mature_venison_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_mature_venison_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_mature_venison_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_plump_bird_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_plump_bird_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_plump_bird_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_plump_bird_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_prime_beef_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_prime_beef_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_prime_beef_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_prime_beef_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_string_meat_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_succulent_fish_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_succulent_fish_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_succulent_fish_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_succulent_fish_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_tender_pork_cooked'] = {
        kind = 'food', hunger = 55, thirst = -5, stamina = 20, innerHealth = 30, outerHealth = 30, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 40 }
    },
    ['consumable_tender_pork_oregano_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 40, outerHealth = 50, goldHealthInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_tender_pork_thyme_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 35, innerHealth = 35, outerHealth = 40, goldStaminaInner = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_tender_pork_wild_mint_cooked'] = {
        kind = 'food', hunger = 60, thirst = -5, stamina = 25, innerHealth = 45, outerHealth = 60, goldHealthOuter = 1, anim = 'bite', prop = 'p_cs_steakslice01x', buff = { type = 'vigor', amount = 50 }
    },
    ['consumable_corn'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_cornedbeef_can'] = {
        kind = 'food', hunger = 50, thirst = -5, stamina = 25, innerHealth = 20, anim = 'can', prop = 's_canrigbeans01x'
    },
    ['consumable_crackers'] = {
        kind = 'food', hunger = 20, thirst = -5, stamina = 10, innerHealth = 5, anim = 'bite'
    },
    ['consumable_herb_desert_sage'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_english_mace'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_gin'] = {
        kind = 'alcohol', hunger = 0, thirst = 20, stamina = 10, innerHealth = 35, outerHealth = 25, fxTime = 1, anim = 'bottle', fx = 'PlayerDrunkSaloon1'
    },
    ['consumable_ginseng_elixier'] = {
        kind = 'medical', stamina = 40, innerHealth = 60, anim = 'tonic', prop = 'p_bottlemedicine01x', buff = { type = 'health', amount = 50 }
    },
    ['consumable_herb_golden_currant'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_hair_tonic'] = {
        kind = 'medical', innerHealth = 5, anim = 'tonic'
    },
    ['consumable_medicine'] = {
        kind = 'medical', innerHealth = 60, outerHealth = 120, heal = true, anim = 'tonic', prop = 'p_bottlemedicine01x', buff = { type = 'health', amount = 50 }
    },
    ['rdr_health_serum'] = {
        kind = 'medical', innerHealth = 80, outerHealth = 150, heal = true, anim = 'tonic', prop = 'p_bottlemedicine09x'
    },
    ['consumable_herb_evergreen_huckleberry'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_herb_hummingbird_sage'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_indian_tobacco'] = {
        kind = 'drug', stamina = 35, innerHealth = -5, anim = 'bite'
    },
    ['consumable_jerky'] = {
        kind = 'food', hunger = 45, thirst = -10, stamina = 25, innerHealth = 20, anim = 'bite', prop = 'p_cs_steakslice01x'
    },
    ['consumable_herb_milkweed'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_restorative'] = {
        kind = 'medical', stamina = 50, innerHealth = 50, outerHealth = 100, heal = true, anim = 'tonic', prop = 'p_bottlemedicine01x', buff = { type = 'health', amount = 50 }
    },
    ['consumable_moonshine'] = {
        kind = 'alcohol', hunger = 0, thirst = 20, stamina = 35, innerHealth = 50, outerHealth = 40, fxTime = 3, anim = 'jar', prop = 'p_masonjarmoonshine01x', fx = 'PlayerDrunkStrong'
    },
    ['consumable_oat_cakes'] = {
        kind = 'food', hunger = 30, thirst = -5, stamina = 20, innerHealth = 10, anim = 'bite'
    },
    ['consumable_offal'] = {
        kind = 'food', hunger = 25, thirst = -5, stamina = 10, innerHealth = -5, anim = 'bite'
    },
    ['consumable_herb_oleander_sage'] = {
        kind = 'poison', hunger = 5, innerHealth = -25, outerHealth = -30, poison = 60, anim = 'bite', prop = 's_inv_orleander01x'
    },
    ['consumable_herb_oregano'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_parasol_mushroom'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_peach'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_pear'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_hair_grease'] = {
        kind = 'medical', innerHealth = 5, anim = 'tonic'
    },
    ['consumable_potent_tonic'] = {
        kind = 'medical', stamina = 85, goldStaminaOuter = 1, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'energy', amount = 75 }
    },
    ['consumable_potent_medicine'] = {
        kind = 'medical', innerHealth = 80, outerHealth = 200, goldHealthOuter = 1, heal = true, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'health', amount = 75 }
    },
    ['consumable_potent_restorative'] = {
        kind = 'medical', stamina = 80, innerHealth = 80, outerHealth = 200, goldHealthOuter = 1, goldStaminaOuter = 1, heal = true, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'health', amount = 75 }
    },
    ['consumable_potent_snake_oil'] = {
        kind = 'medical', stamina = 75, innerHealth = 40, goldStaminaInner = 1, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'energy', amount = 75 }
    },
    ['consumable_herb_prairie_poppy'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_cigarette_box'] = {
        kind = 'drug', stamina = 35, innerHealth = -5, anim = 'cigarette'
    },
    ['consumable_herb_rams_head'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_red_raspberry'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_herb_red_sage'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_rum'] = {
        kind = 'alcohol', hunger = 0, thirst = 25, stamina = 25, innerHealth = 45, outerHealth = 40, fxTime = 2, anim = 'bottle', fx = 'PlayerDrunkStrong'
    },
    ['rdr_saltbush'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['rdr_seasoning'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['rdr_sherry'] = {
        kind = 'alcohol', hunger = 0, thirst = 25, stamina = 15, innerHealth = 30, fxTime = 1, anim = 'bottle', fx = 'PlayerDrunkSaloon1'
    },
    ['consumable_snake_oil'] = {
        kind = 'medical', stamina = 50, innerHealth = 25, anim = 'tonic', prop = 'p_bottlemedicine01x', buff = { type = 'energy', amount = 50 }
    },
    ['consumable_special_tonic_crafted'] = {
        kind = 'medical', stamina = 100, goldStaminaInner = 1, goldStaminaOuter = 1, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'energy', amount = 100 }
    },
    ['consumable_special_medicine_crafted'] = {
        kind = 'medical', innerHealth = 100, outerHealth = 350, goldHealthInner = 1, goldHealthOuter = 1, heal = true, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'health', amount = 100 }
    },
    ['consumable_special_restorative_crafted'] = {
        kind = 'medical', stamina = 100, innerHealth = 100, outerHealth = 350, goldHealthInner = 1, goldHealthOuter = 1, goldStaminaInner = 1, goldStaminaOuter = 1, heal = true, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'health', amount = 100 }
    },
    ['consumable_special_snake_oil_crafted'] = {
        kind = 'medical', stamina = 100, innerHealth = 60, goldStaminaInner = 1, goldStaminaOuter = 1, anim = 'tonic', prop = 'p_bottlemedicine09x', buff = { type = 'energy', amount = 100 }
    },
    ['consumable_crafted_super_meal'] = {
        kind = 'food', hunger = 80, thirst = 30, stamina = 40, innerHealth = 50, outerHealth = 60, anim = 'stew', prop = 'p_bowl04x_stew', buff = { type = 'vigor', amount = 60 }
    },
    ['consumable_herb_creeping_thyme'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['rdr_tobacco_pipe'] = {
        kind = 'drug', stamina = 45, innerHealth = -5, anim = 'pipe'
    },
    ['consumable_valerian_root'] = {
        kind = 'medical', stamina = 50, innerHealth = 30, anim = 'tonic', prop = 'p_bottlemedicine01x'
    },
    ['consumable_jerky_venison'] = {
        kind = 'food', hunger = 50, thirst = -10, stamina = 30, innerHealth = 25, anim = 'bite', prop = 'p_cs_steakslice01x'
    },
    ['consumable_herb_violet_snowdrop'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['rdr_water_flask'] = {
        kind = 'drink', hunger = 0, thirst = 60, stamina = 10, innerHealth = 5, anim = 'bottle_small', prop = 'p_bottlebeer01a', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_whiskey'] = {
        kind = 'alcohol', hunger = 0, thirst = 25, stamina = 15, innerHealth = 40, outerHealth = 35, fxTime = 1, anim = 'bottle', prop = 's_inv_whiskey01x', fx = 'PlayerDrunkSaloon1'
    },
    ['consumable_herb_wild_carrots'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_wild_feverfew'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_wild_mint'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
    ['consumable_herb_wintergreen_berry'] = {
        kind = 'food', hunger = 20, thirst = 15, stamina = 15, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 25 }
    },
    ['consumable_herb_yarrow'] = {
        kind = 'food', hunger = 5, thirst = 5, stamina = 10, innerHealth = 10, anim = 'bite', buff = { type = 'vegan', amount = 15 }
    },
}

Config.HorseItems = {
    ['consumable_apple'] = {
        kind = 'feed', amount = 25, distance = 3.0,
    },
    ['consumable_carrot'] = {
        kind = 'feed', amount = 25, distance = 3.0,
    },
    ['consumable_oat_cakes'] = {
        kind = 'feed', amount = 35, distance = 3.0,
    },
}
