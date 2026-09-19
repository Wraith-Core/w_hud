-- w_hud — إعدادات السيرفر التي يضبطها الأدمن من لوحة الهود
--
-- صفٌّ واحد لأنّ السيرفر واحد: اسم السيرفر وشعاره، وسرعة نقصان الجوع والعطش،
-- والضرر الناتج عنهما، وأيُّ خصائص الهود مُفعَّلة للجميع.
--
-- يُنشأ تلقائيًّا عند تشغيل المورد؛ هذا الملفّ للمرجع والتثبيت اليدويّ.
--
-- ⚠️ القيم تُقصّ في server/admin.lua قبل أن تُخزَّن وقبل أن تُطبَّق — لا لأنّ
--    الأدمن متَّهم، بل لأنّ interval = 0 حلقةٌ بلا انتظار في عمليّة السيرفر
--    نفسها ولكلّ اللاعبين معًا.
CREATE TABLE IF NOT EXISTS `w_hud_server` (
    `id`      TINYINT NOT NULL DEFAULT 1, -- دائمًا ١
    `data`    TEXT NOT NULL,              -- JSON: name + logo + needs + damage + features
    `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- لمنح شخصٍ صلاحيّة تعديلها من داخل اللعبة، أضف في server.cfg:
--     add_ace group.admin w_hud.admin allow
