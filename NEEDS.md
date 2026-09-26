# w_hud — نظام الحاجات

يحلّ `w_hud` محلّ `vorp_metabolism` كاملًا: الجوع والعطش والمنشّطات والتسمُّم
المؤقّت والعناية بالخيل والحقائب — كلُّها في موردٍ واحد، سلطتُها على السيرفر،
وتُحفظ في `w_hud_needs`.

> ⚠️ **عطّل `vorp_metabolism`** من `server.cfg`:
> `#ensure vorp_metabolism`
> إن بقي يعمل نقصت الحاجاتُ مرّتين واختلفت القيمُ بين الاثنين.
> المورد يطبع تحذيرًا في الكونسول إن وجده يعمل.

---

## الملفّات

| الملفّ | ماذا فيه |
|---|---|
| `shared/config.lua` | إعدادات الهود العامّة: الخريطة والبوصلة والحرارة ومفتاح اللوحة |
| `shared/needs.lua` | إعدادات الحاجات: المنشّطات · الصوت · العناية بالخيل · التذهيب · التسمُّم · العتبات |
| `shared/consumables.lua` | **الجدول المُنتقى** (اثنا عشر غرضًا في ستّة أزواج) + أغراض الخيل |
| `shared/consumables_ported.lua` | الأصناف المنقولة من bln_hud — تملأ ما تركه الجدول المُنتقى فارغًا فقط |
| `shared/satchels.lua` | الحقائب: درجاتها وما تزيده على الحمولة |
| `shared/wheel.lua` | عجلة الأسلحة: إعداداتها وجدول إحصاءات كل سلاح في RDR2 |
| `server/metabolism.lua` | نواة الحاجات: الحفظ · الاضمحلال · المنشّطات |
| `server/consumables.lua` | تسجيل الأصناف في الحقيبة النشطة (عبر w_lib) وتطبيق أثرها |
| `server/satchels.lua` | تطبيق الحقيبة على سعة الحمولة عند كل دخول |
| `server/admin.lua` | إعدادات السيرفر التي يضبطها الأدمن من لوحة الهود |
| `client/needs.lua` | استقبال الحاجات وتطبيق المنشّطات على الشخصيّة وتوافق vorp_metabolism |
| `client/consumables.lua` | حركات الأكل والشرب والدعائم والنوى والتذهيب والتسمُّم ومؤثّر الشاشة |
| `client/voice.lua` | مستوى الصوت: أربع درجات على عجلة الماوس |
| `client/wheel.lua` · `client/inventory.lua` | عجلة الأسلحة ومحرّكها وجسر الحقيبة |

---

## الحاجات

كلُّها بمقياس **٠–١٠٠**.

| الحاجة | ٠ يعني | ١٠٠ يعني |
|---|---|---|
| `hunger` | يتضوّر جوعًا | شبعان |
| `thirst` | يموت عطشًا | مرتوٍ |

النظافة (`cleanliness`) تُحسب في العميل من اتّساخ الشخصيّة ولا تُحفظ.

---

## ١. الاضمحلال والضرر

* سرعة النقصان وطول الدورة يضبطها الأدمن من لوحة الهود (`server/admin.lua`)، والقيم
  الافتراضيّة في `shared/config.lua`.
* حين ينزل الجوع أو العطش تحت العتبة تُخصم صحّةٌ كل دورة، ويُخبَر اللاعب بتنبيه.
* إن عُطّل «القتل» تقف الصحّة قبل الموت بقليل.

## ٢. المنشّطات

خمسة أنواع، كلٌّ منها ٠–١٠٠ وينحسر تلقائيًّا:

| النوع | الأثر | من أين |
|---|---|---|
| `health` | يجدّد الصحّة | التونيك · الحقنة |
| `cowboy` | يجدّد لياقة آخر خيلٍ رُكب | المونشاين |
| `vegan` | يجدّد الجوع والعطش | الماء · اليخنة · الخضار |
| `energy` | يجدّد لياقة اللاعب | القهوة · السكّر |
| `vigor` | يجدّد نواة الصحّة | اللحم المشوي |

## ٣. التذهيب

التونيك وحده يُذهّب النوى: `goldHealthOuter` يُحصّن الحلقة و`goldHealthInner`
الأيقونة (وكذلك الستامينا). في الهود أيٌّ منهما يجعل الدائرة كلّها بلون المعزِّز
(لون معزز الصحة / لون معزز اللياقة من قائمة الهود)، ودوائر الحصان كذلك مع أدوية
الخيل ومنشّطاتها من w_stables. المدّة في `Config.Gold.Duration`.

## ٤. التسمُّم

حالةٌ مؤقّتة في ذاكرة العميل لا تُحفظ: اللحم الفاسد وزهرة الدفلى تُسمّم لعدد
ثوانٍ (`poison`)، فتأخذ دائرة الصحة نفسها لون التسمُّم (من قائمة الهود ← الألوان) وتُخصم صحّةٌ كل دورة ولا يقتل
(`Config.Poison.MinHealth`). الترياق: أي غرض فيه `curesPoison = true`. الموت يُبطله.

## ٥. العناية بالخيل

استعمل الغرض وأنت بجانب آخر خيلٍ ركبته (٣ أمتار):

| النوع | الأثر |
|---|---|
| `kind = 'feed'` | +صحّة الخيل |
| `kind = 'stamina'` | +لياقة الخيل |
| `kind = 'brush'` | تنظيف بلا استهلاك |

غرضٌ موجود في الجدولين معًا (`Config.Consumables` و`Config.HorseItems`) يذهب
للخيل إن كان قريبًا، وإلّا أكله اللاعب.

## ٦. الحقائب

درجات لا تراكم: الحقيبة الأكبر تحلّ محلّ الأصغر، ودرجةٌ مملوكة تُرفض ولا
تُستهلك. الجدول في `shared/satchels.lua` والحمولة في `w_hud_satchels`.

---

## إضافة صنفٍ جديد

افتح `shared/consumables.lua` وأضف مدخلًا — لا شيء غيره (والاسم المعروض من
`locales/{ar,en}.json` تحت `item.<name>`):

```lua
['my_soup'] = {
    kind = 'food',
    hunger = 35, thirst = 15, stamina = 15,
    innerHealth = 20, outerHealth = 15,
    prop = 'p_bowl04x_stew', anim = 'stew',
    buff = { type = 'vegan', amount = 50 },
    giveBack = { item = 'empty_bottle', amount = 1 },
},
```

الحركات المتاحة: `bite` · `can` · `stew` · `mug` · `bottle` · `bottle_small` ·
`jar` · `glass` · `canteen` · `tonic` · `cigarette` · `cigar` · `pipe` ·
`syringe` · `bandage` (والأسماء القديمة `eat` · `drink` · `coffee` · `smoke`
ما زالت تعمل).

> اسمٌ خاطئ للدعامة (`prop`) لا يكسر شيئًا — تُتخطّى الدعامةُ وحدها
> وتبقى الحركة (`IsModelValid` يحرسها).

> ⚠️ ما يُذكر هنا يجب أن يوجد في جدول أغراض الحقيبة، وإلّا سُجّل أثرٌ لغرضٍ
> لا يملكه أحد.

---

## الواجهة البرمجيّة

### السيرفر

```lua
exports.w_hud:GetNeeds(src)                 -- كل الحاجات + المنشّطات
exports.w_hud:GetNeed(src, 'hunger')
exports.w_hud:SetNeed(src, 'hunger', 100)
exports.w_hud:AddNeed(src, 'thirst', 20)
exports.w_hud:AddNeeds(src, { hunger = 20, thirst = 10 })  -- بثٌّ واحد
exports.w_hud:ResetNeeds(src)               -- بعد الإحياء
exports.w_hud:SaveNeeds(src)

exports.w_hud:GiveBuff(src, 'health', 50)
exports.w_hud:GetBuffs(src)
exports.w_hud:ClearBuffs(src)

exports.w_hud:GetSatchelBonus(src)
exports.w_hud:GetCarryWeight(src)
exports.w_hud:IsHudAdmin(src)
exports.w_hud:GetServerHudCfg()
```

### العميل

```lua
exports.w_hud:GetNeeds()                    -- الحاجات الحاليّة
exports.w_hud:GetBuffs()
exports.w_hud:SetDisplay('hunger', { show = false })   -- إخفاء عنصر
exports.w_hud:RefreshDisplay()
exports.w_hud:isPoisoned() · poisonPlayer(seconds) · curePoison()
exports.w_hud:GetVoiceLevel() · SetVoiceLevel(i)
exports.w_hud:OpenHudSettings() · CloseHudSettings() · GetHudSettings()
exports.w_hud:isWheelOpen() · isWheelEnabled()
```

### أحداث

```lua
-- العميل → السيرفر
TriggerServerEvent('w_hud:server:setNeed', 'hunger', 50)
TriggerEvent('w_hud:client:giveBuff', 'health', 40)

-- السيرفر → العميل
TriggerClientEvent('w_hud:client:poison', src, 45)
TriggerClientEvent('w_hud:client:curePoison', src)
```

**أحداث السكربتات القديمة على RedM تعمل كما كانت:**
`givebufftoplayerhealth` · `givebufftoplayercowboy` · `givebufftoplayervegan`

**أحداث vorp_metabolism تعمل أيضًا** (بمقياسها ٠–١٠٠٠):
`vorpmetabolism:changeValue` · `vorpmetabolism:setValue` ·
`vorpmetabolism:getValue` · `vorpmetabolism:setHud`

---

## الأوامر

| الأمر | ماذا يفعل |
|---|---|
| `/hudmenu` · `/hudsettings` | لوحة الهود (المفتاح الافتراضي `Config.HudMenuKey`) |
| `/voice [1-4 \| up \| down]` | مستوى الصوت |
| `/feed [amount] [id]` | ملء الجوع والعطش (أدمن) |
| `/satchel <id> <tier\|reset>` | منح حقيبة أو إزالتها (أدمن) |
| `/hudall` · `/hudev` · `/hudset` · `/hudadd` · `/hudsweep` · `/hudgold` | معاينة وتجربة الهود |
| `/hudfx` · `/hudhide` · `/hidecomp` · `/mapdebug` · `/fwdebug` · `/needsdebug` · `/wheeldebug` | تشخيص |

---

## إيقاف نظامٍ كاملًا

```lua
Config.Systems = {
    buffs = true, horseCare = true, consumables = true,
}
```

---

## قاعدة البيانات

تُنشأ الجداول تلقائيًّا عند الإقلاع: `w_hud_needs` · `w_hud_satchels` ·
`w_hud_settings` · `w_hud_server`. النسخ اليدويّة في `sql/`.

---

## بعد التعديل

```
refresh
restart w_hud
```

وإن عدّلت `web/src` فابنِ الواجهة أوّلًا:

```
cd web && npm run build
```
