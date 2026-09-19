if Config.Locale ~= 'en' then return end

Lang = Locale:new({
    phrases = {
        error = {},
        success = {},
        info = {
            getstress = 'You feel stressed',
            thirsty = 'You are a little thirsty',
            relaxing = 'You are relaxing',
        },
    },
    warnOnMissing = true,
})
