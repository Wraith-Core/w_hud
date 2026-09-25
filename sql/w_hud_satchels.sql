-- w_hud — جدول الحقائب: ما تزيده حقيبة كل شخصيّة على الحمولة الأساسيّة
-- يُنشأ تلقائيًّا عند تشغيل المورد؛ هذا الملفّ للمرجع/التثبيت اليدويّ.
CREATE TABLE IF NOT EXISTS `w_hud_satchels` (
    `cid`   VARCHAR(64) NOT NULL,   -- معرّف الشخصية (نفس مفتاح w_hud_needs)
    `bonus` INT NOT NULL DEFAULT 0, -- الزيادة بالغرام
    `rank`  INT NOT NULL DEFAULT 0, -- درجة الحقيبة
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
