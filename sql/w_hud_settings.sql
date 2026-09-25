-- w_hud — جدول إعدادات الواجهة لكلِّ شخصية
-- (المواقع والألوان والأحجام التي يضبطها اللاعب من لوحة التحكُّم)
--
-- يُنشأ تلقائيًّا عند تشغيل المورد؛ هذا الملفّ للمرجع والتثبيت اليدويّ.
--
-- ⚠️ العمود data نصٌّ مُعمّى عن الخادم: لا يقرأ داخله أحد سوى الواجهة نفسها،
--    وهي تتحقّق من كلّ رقمٍ فيه قبل أن ترسم به (mergeSettings في web/src/settings/types.ts).
CREATE TABLE IF NOT EXISTS `w_hud_settings` (
    `cid`     VARCHAR(64) NOT NULL, -- معرّف الشخصية (نفس مفتاح w_hud_needs)
    `data`    TEXT NOT NULL,        -- JSON: theme + widgets + grid + scale
    `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
