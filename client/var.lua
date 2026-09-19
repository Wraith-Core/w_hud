hunger = 100
thirst = 100
cleanliness = 100

-- -- arrives from the server via w_hud:client:needs ------------------------
buffs    = {}  -- active buffs { health = 40, vigor = 20, ... }
voiceLevel = 2 -- voice level 1..4 (client/voice.lua)
cash = 0
gold = 0
bank = 0   -- the sum of every bank account this character holds
dirty = 0  -- black money (VORP blackmoney)
isLoggedIn = false
youhavemail = false
incinematic = false
inBathing = false
inClothing = false
showUI = true
temperature = 0
temp = 0
tempadd = 0
clean = 0
show = true
hideStement = false

weatherNames = {
    [-702816767] = "FOGGY",
    [2137137442] = "GROUND BLIZZARD",
    [1974067816] = "HAIL",
    [821931868] = "CLOUDS",
    [-1721991356] = "DRIZZLE",
    [-173507739] = "HIGH PRESSURE",
    [839715153] = "HURRICANE",
    [1500834021] = "MISTY",
    [-1148613331] = "OVERCAST",
    [433385945] = "OVERCAST DARK",
    [1420204096] = "RAIN",
    [-1317052143] = "SANDSTORM",
    [-416908843] = "SHOWER",
    [212278652] = "SLEET",
    [-273223690] = "SNOW",
    [603685163] = "SNOW LIGHT",
    [1632247697] = "SUNNY",
    [-1233681761] = "THUNDER",
    [2082228755] = "THUNDER STORM",
    [725623432] = "WHITE OUT",
    [669657108] = "BLIZZARD"
}