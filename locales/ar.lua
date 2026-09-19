if Config.Locale ~= 'ar' then return end

Lang = Locale:new({
    phrases = {
        error = {},
        success = {},
        info = {
            getstress = 'أنت تشعر بالتوتر',
            thirsty = 'أنت عطشان قليلاً',
            relaxing = 'أنت تسترخي',
        },
    },
    warnOnMissing = true,
})
