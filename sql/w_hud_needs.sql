-- w_hud — جدول قيم الحاجات
-- يُنشأ تلقائيًّا عند تشغيل المورد؛ هذا الملفّ للمرجع/التثبيت اليدويّ.
CREATE TABLE IF NOT EXISTS `w_hud_needs` (
    `cid`      VARCHAR(64) NOT NULL,
    `hunger`   INT DEFAULT 100, -- الجوع    ١٠٠ = شبعان
    `thirst`   INT DEFAULT 100, -- العطش    ١٠٠ = مرتوٍ
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- أعمدة الأنظمة المحذوفة (لم يعد المورد يقرؤها ولا يكتبها؛ احذفها إن كان جدولك قديمًا):
-- ALTER TABLE `w_hud_needs` DROP COLUMN `stress`, DROP COLUMN `toxicity`, DROP COLUMN `bladder`, DROP COLUMN `bowel`;
