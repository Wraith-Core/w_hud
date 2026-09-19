-- ════════════════════════════════════════════════════════════════════════════
-- w_hud — جدول الاستهلاكيّات
--
-- ═══ لماذا أُعيد بناؤه ═══
--
-- كان فيه تسعون غرضاً بلا تبويب: السكرُ بين الأكل، والدواءُ بين الحلوى، وستّة
-- أنواع ويسكي بأرقامٍ متطابقة. واثنان وعشرون منها تُشير إلى أغراضٍ **لا وجود
-- لها في الحقيبة أصلاً** — أي سطورٌ تُسجّل غرضاً لا يملكه أحد ولا يُستعمل أبداً.
--
-- فصار اثني عشر غرضاً في ستّة أزواج، لكلّ زوجٍ عملُه ولا يُغني عن غيره:
--
--     أكلٌ وشرب        cooked_meat · water
--     بوست لاعب        herbal_tonic · tonic_bitters
--     خمرٌ وسُكر        whisky · absinthe
--     تسمُّم            rotten_meat · oleander_sage
--     منشّطات           morphine_shot · painkiller
--     بوست خيل         horse_reviver · consumable_horsepeppermints   ← Config.HorseItems
--
-- ★ الخيل في جدولٍ منفصل لأنّ مساره مختلف: يُشترط قربُ الحصان، وتُشغَّل حركة
--   تفاعلٍ معه، ويذهب الأثر إلى كوراته لا إلى كورات اللاعب. خلطُه بالطعام كان
--   يعني حقلَي `kind` مختلفين في جدولٍ واحد.
--
-- ═══ العقد مع الحقيبة ═══
--
-- ⚠️ **ما يُذكر هنا يجب أن يوجد في w_inventory/data/items.lua**. هذا الملفّ
--   يمنح الأثر، وذاك يمنح الوجود. غرضٌ هنا بلا تعريفٍ هناك = تسجيلٌ لغرضٍ
--   لا يملكه أحد، وهو بعينه ما جعل الجدول القديم يبدو عاملاً وهو ميّت.
--
-- ★ عطِّل vorp_metabolism في server.cfg — وإلّا نقصت الحاجات مرّتين.
--
-- ── مقياس القيم ─────────────────────────────────────────────────────────────
--   hunger · thirst        الجوع والعطش ٠-١٠٠ (الموجب يرفع)
--   stamina                كور الستامينا الداخليّ ٠-١٠٠
--   innerHealth            كور الصحّة الداخليّ ٠-١٠٠
--   outerHealth            صحّة الكيان مباشرةً (مقياس RDR ٠-٦٠٠)
--   goldHealth* / goldStamina*   التذهيب — Outer يُذهّب الحلقة و Inner الأيقونة معها
--                          (والرقم مقدارٌ لا مدّة؛ المدّة في Config.Gold.Duration)
--
-- ── حقول الغرض ──────────────────────────────────────────────────────────────
--   (the display name is locale('item.<name>') from locales/{ar,en}.json)
--   kind        food · drink · alcohol · medical · drug · poison
--   anim        أسلوب الاستهلاك — كلٌّ مبنيّ على حركة اللعبة الأصليّة لذلك الشكل
--               bite (طعام باليد) · can (علبة) · stew (وعاء/طبق بملعقة) · mug (مشروب ساخن)
--               bottle (زجاجة طويلة) · bottle_small (زجاجة قصيرة) · jar (برطمان) · glass (كأس)
--               canteen · tonic (قارورة دواء صغيرة) · cigarette · cigar · pipe · syringe · bandage
--               (eat · drink · coffee · smoke القديمة ما زالت تعمل كأسماء بديلة)
--   prop        المجسّم المحمول — اختياريّ؛ لكلّ أسلوب مجسّمه الافتراضيّ. الأسماء في client/consumables.lua
--   fx, fxTime  مؤثّر الشاشة (animpostfx) ومدّته بالدقائق
--   giveBack    { item = 'empty_bottle', amount = 1 }  يُعاد بعد الاستعمال
--   buff        { type = '…', amount = 50 }  الأنواع في shared/needs.lua
--   heal        true = يشفي النزف/الكسر إن وُجد نظامٌ طبّيّ
--   poison      عددُ **ثوانٍ** من التسمُّم (القلب يخضرّ ويُدخّن)
--   curesPoison true = يُبطل التسمُّم فوراً
--
-- ★ كلّ حقلٍ اختياريّ: ما لم يُذكر = صفرٌ أو لا شيء.
-- ════════════════════════════════════════════════════════════════════════════

Config.Consumables = {

    -- ════════════════════════════════════════════════════════════════════
    -- ١ · أكلٌ وشرب — سدُّ الجوع والعطش، لا أكثر
    --
    -- ★ لا تذهيب هنا عمداً: التذهيب مكافأةُ التونيك لا ثمنُ رغيف. ولو ذهّب
    --   الطعامُ العاديّ لما بقي للزوج الثاني معنى.
    -- ════════════════════════════════════════════════════════════════════

    ['cooked_meat'] = {
        kind = 'food',
        hunger = 45, thirst = -5, stamina = 10,
        innerHealth = 15, outerHealth = 20,
        buff = { type = 'vigor', amount = 40 },
        anim = 'bite', prop = 'p_cs_steakslice01x',
    },

    ['water'] = {
        kind = 'drink',
        hunger = 0, thirst = 60, stamina = 5,
        innerHealth = 5,
        giveBack = { item = 'empty_bottle', amount = 1 },
        buff = { type = 'vegan', amount = 25 },
        anim = 'bottle_small', prop = 'p_water01x',
    },

    -- ════════════════════════════════════════════════════════════════════
    -- ٢ · بوست اللاعب — التونيك، وهو وحده ما يُذهّب
    --
    -- ★ واحدٌ للصحّة وواحدٌ للنشاط، ولا يُغني أحدهما عن الآخر. ومنقوع الأعشاب
    --   هو **ترياق السمّ** كذلك، فله سببان لحمله.
    -- ════════════════════════════════════════════════════════════════════

    ['herbal_tonic'] = {
        kind = 'medical',
        hunger = 5, thirst = 20,
        innerHealth = 60, outerHealth = 150,
 -- تذهيبٌ كامل لكور الصحّة: الحلقة والأيقونة معاً
        goldHealthInner = 1, goldHealthOuter = 1,
        buff = { type = 'health', amount = 60 },
        curesPoison = true,
        heal = true,
        anim = 'tonic', prop = 'p_bottlemedicine09x',
    },

    ['tonic_bitters'] = {
        kind = 'medical',
        hunger = 0, thirst = 15, stamina = 70,
        innerHealth = 10,
 -- تذهيبٌ كامل لكور الستامينا
        goldStaminaInner = 1, goldStaminaOuter = 1,
        buff = { type = 'energy', amount = 60 },
        anim = 'tonic', prop = 'p_bottlemedicine09x',
    },

    -- ════════════════════════════════════════════════════════════════════
    -- ٣ · خمرٌ وسُكر — يُداوي البدن ويُذهب الصحو
    --
    -- ★ الفرق بينهما في السُّكر لا في الشفاء: الويسكي يُدفئ، والأفسنتين
    --   يُسكِر ضِعفَه ومؤثّرُه أقوى وأطول. فمن أراد الشفاء شرب الويسكي، ومن
    --   أراد السُّكر شرب الأفسنتين — ولكلٍّ ثمنُه.
    -- ════════════════════════════════════════════════════════════════════

    ['whisky'] = {
        kind = 'alcohol',
        hunger = 0, thirst = 30, stamina = 10,
        innerHealth = 45, outerHealth = 40,
        fx = 'PlayerDrunkSaloon1', fxTime = 1,
        giveBack = { item = 'empty_bottle', amount = 1 },
        anim = 'bottle', prop = 's_inv_whiskey01x',
    },

    ['absinthe'] = {
        kind = 'alcohol',
        hunger = 0, thirst = 20, stamina = 15,
        innerHealth = 30, outerHealth = 20,
 -- ★ PlayerDrunkStrong لا Saloon1: هذا هو الفرق المحسوس بين الاثنين.
        fx = 'PlayerDrunkStrong', fxTime = 3,
        giveBack = { item = 'empty_bottle', amount = 1 },
        anim = 'bottle', prop = 'p_bottleabsinthe01x',
    },

    -- ════════════════════════════════════════════════════════════════════
    -- ٤ · التسمُّم — القلب يخضرّ ويُدخّن
    --
    -- ★ الحقل `poison` ثوانٍ لا مقدار. والأثر مشروحٌ في shared/needs.lua
    --   تحت Config.Poison: ضربةٌ كلّ ثانيتين تُنقص الصحّة ولا تقتل، وقلبٌ
    --   أخضر يتصاعد منه دخان.
    --
    -- ⚠️ ولهما ترياق: منقوع الأعشاب (curesPoison). سمٌّ بلا ترياقٍ عقوبةٌ
    --   لا لعبة.
    -- ════════════════════════════════════════════════════════════════════

    ['rotten_meat'] = {
        kind = 'poison',
 -- ★ يسدّ الجوع فعلاً: هذا ما يجعله فخّاً. جائعٌ في البرّيّة يأكله
 --   فيشبع ثمّ يندم — ولو لم يُشبع لما أكله أحدٌ ولا صار للسمّ معنى.
        hunger = 25, thirst = -10,
        innerHealth = -25, outerHealth = -30,
        poison = 45, -- ثانية
        anim = 'bite', prop = 'p_meatchunks01x_raw',
    },

    -- ! Capitalised to match the row this server already holds (Oleander_Sage). The
    --    items table's key is case-insensitive, so the row was found when it was
    --    written; vorp_inventory's in-memory lookup is case-sensitive, so a lowercase
    --    name here registers an item the bag can never match to that row.
    ['Oleander_Sage'] = {
        kind = 'poison',
        hunger = 5,
        innerHealth = -15, outerHealth = -20,
 -- ★ أطول من اللحم الفاسد: هذه زهرةٌ سامّة تُصنع منها السموم، ومن
 --   يأكلها يأكلها قصداً أو جهلاً — وكلاهما يستحقّ دقيقة.
        poison = 60,
        anim = 'bite', prop = 's_inv_orleander01x',
    },

    -- ════════════════════════════════════════════════════════════════════
    -- ٥ · المنشّطات — صحّةٌ فوريّة بلا شبع
    --
    -- ★ ما يفرقها عن التونيك: لا تُذهّب ولا تُشبع، بل تُعيد الصحّة دفعةً
    --   واحدة. دواءُ اشتباكٍ لا دواءُ استعداد.
    -- ════════════════════════════════════════════════════════════════════

    ['morphine_shot'] = {
        kind = 'drug',
        stamina = 45,
        innerHealth = 40, outerHealth = 250,
        buff = { type = 'health', amount = 50 },
        heal = true,
        anim = 'syringe', prop = 's_inv_syringe01x',
    },

    ['painkiller'] = {
        kind = 'drug',
        stamina = 25,
        innerHealth = 20, outerHealth = 120,
        buff = { type = 'vigor', amount = 45 },
        anim = 'tonic', prop = 'p_bottlemedicine03x',
    },
}

-- ════════════════════════════════════════════════════════════════════════════
-- ٦ · بوست الخيل — جدولٌ منفصل لأنّ مساره منفصل
--
-- ★ لا يُستعملان كالطعام: يُشترط قربُ الحصان (distance)، وتُشغَّل حركة تفاعلٍ
--   معه، ويذهب الأثر إلى كوراته هو. ومن استعملهما بعيداً عن حصانه قيل له
--   «اقترب من خيلك أوّلًا» ولم يُستهلك الغرض.
--
--   kind = 'feed'     يرفع كور صحّة الحصان
--   kind = 'stamina'  يرفع كور نشاطه
--   kind = 'brush'    تنظيفٌ بلا استهلاك
-- ════════════════════════════════════════════════════════════════════════════

Config.HorseItems = {
    ['horse_reviver'] = {
        kind = 'feed', amount = 60, distance = 3.0,
    },

    ['consumable_horsepeppermints'] = {
        kind = 'stamina', amount = 45, distance = 3.0,
    },
}
