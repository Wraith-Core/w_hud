local Translations = {
    error = {
        
    },
    success = {
        
    },
    info = {
        getstress = "Du wirkst gestresst",
        thirsty = "Du wirkst ein wenig durstig",
        relaxing = "Du beruhigst dich",
    }
}

if GetConvar('w_locale', GetConvar('rsg_locale', 'en')) == 'de' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
