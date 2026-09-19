// Wraith HUD — logic

var staminaOldUpdate = 115;
var hungerOldUpdate = 101;
var thirstOldUpdate = 101;
var brainOldUpdate = 101;
var healthOldUpdate = 101;
var armourOldUpdate = 101;
var horseStaminaOldUpdate = 100;
var horseHealthOldUpdate = 100;
var oldCash = -1
var oldGold = -1
var fuckyxa = 0
var fuckAboJmal = 0
$("body").fadeOut(0);
$('.talking-stats,.radio-wave,.mountComp, #playerBank, #playerCash, .live-server').hide();

function animateNumber(element, startValue, endValue, duration) {
    let startTime = null;
    const $element = $(element);
    var val = endValue - startValue;
    var incressed = parseFloat(val.toFixed(2));
    var sigg = '-';
    function updateNumber(currentTime) {
        if (!startTime) startTime = currentTime;
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);

        const currentValue = parseFloat((startValue + (endValue - startValue) * progress).toFixed(2));

        $element.text(currentValue.toFixed(2)); 
        if (endValue > startValue) {
            sigg = '+'; 
        } else if (endValue < startValue) {
            sigg = ''; 
        }
        
        if (progress < 1) {
            requestAnimationFrame(updateNumber);
        } else {
            $element.text(currentValue.toFixed(2) + ' ' + sigg + '' + incressed.toFixed(2) + ''); 
            setTimeout(() => {
                $element.text(currentValue.toFixed(2)); 
            }, 3000);
        }
    }

    requestAnimationFrame(updateNumber);
}

playHudSound = function (sndId) {
    if (sndId == 1) {
        var notify = document.getElementById("priority-sound");
        notify.currentTime = 0;
        notify.play();
        notify.volume = 1.0;
    } else if (sndId == 2) {
        var notifyrp = document.getElementById("notifyrp");
        notifyrp.currentTime = 0;
        notifyrp.play();
        notifyrp.volume = 1.0;
    }
};

var direction = 0;
document.addEventListener('DOMContentLoaded', function () {
    window.addEventListener('message', function (event) {
        var data = event.data;

        var compassAngleData = data.compassDirection;

        if (data.comp === 'setCompassDirection') {
            if (compassAngleData > 0 && compassAngleData < 20) {
                direction = compassAngleData + 7;
            } else if (compassAngleData >= 20 && compassAngleData < 40) {
                direction = compassAngleData + 25;
            } else if (compassAngleData >= 40 && compassAngleData < 60) {
                direction = compassAngleData + 30;
            } else if (compassAngleData >= 60 && compassAngleData < 80) {
                direction = compassAngleData + 35;
            } else if (compassAngleData >= 80 && compassAngleData < 100) {
                direction = compassAngleData + 40;
            } else if (compassAngleData >= 100 && compassAngleData < 120) {
                direction = compassAngleData + 50;
            } else if (compassAngleData >= 120 && compassAngleData < 140) {
                direction = compassAngleData + 55;
            } else if (compassAngleData >= 140 && compassAngleData < 160) {
                direction = compassAngleData + 63;
            } else if (compassAngleData >= 160 && compassAngleData < 180) {
                direction = compassAngleData + 66;
            } else if (compassAngleData >= 180 && compassAngleData < 200) {
                direction = compassAngleData + 65;
            } else if (compassAngleData >= 200 && compassAngleData < 220) {
                direction = compassAngleData + 70;
            } else if (compassAngleData >= 220 && compassAngleData < 240) {
                direction = compassAngleData + 85;
            } else if (compassAngleData >= 240 && compassAngleData < 260) {
                direction = compassAngleData + 91;
            } else if (compassAngleData >= 260 && compassAngleData < 280) {
                direction = compassAngleData + 97;
            } else if (compassAngleData > 280 && compassAngleData < 300) {
                direction = compassAngleData + 99;
            } else if (compassAngleData > 300 && compassAngleData < 320) {
                direction = compassAngleData + 110;
            } else if (compassAngleData > 320 && compassAngleData < 340) {
                direction = compassAngleData + 115;
            }
            $('.compdirect').css('top', - direction + '%')
        }
    });
});


(() => {
    WHUD = {};

    WHUD.UpdateHud = function (data) {

        
        if (data.show != undefined) {
            if (data.show == false) {
                $('.moneyInfo').fadeOut(200);
                $('.hud-holder').fadeOut(200);
                return;
            } else {
                $('.moneyInfo').fadeIn(200);
                $('.hud-holder').fadeIn(200);
            }
        }
        $("body").fadeIn();
        if (data.health != undefined) {
            $('#health_bars').css("height", data.health * 1.59 + '%');
        }

        if (data.cash !== oldCash) {
            fuckyxa = oldCash;
            oldCash = data.cash;
            $('#playerCash').html(`<span class="infoDiv" id="playerCash"> <span class="infoDiv-icon" id="infoDiv-cashicon"><i class="fa-solid fa-sack-dollar"></i> </span> <span class="infoDiv-data" id="infoDiv-dataCash">${data.cash}</span> </span>`).fadeIn(200);
            animateNumber('#infoDiv-dataCash', fuckyxa, data.cash, 3000); 
            setTimeout(() => {
                $('#playerCash').fadeOut(200);
            }, 9000);
        }
    

        if (data.gold !== oldGold) {
            fuckAboJmal = oldGold;
            oldGold = data.gold;
            $('#playerGold').html(`<span class="infoDiv" id="playerGold"> <span class="infoDiv-icon" id="infoDiv-Goldicon"><i class="fa-solid fa-coins"></i> </span> <span class="infoDiv-data" id="infoDiv-dataGold">${data.gold}</span> </span>`).fadeIn(200);
            animateNumber('#infoDiv-dataGold', fuckAboJmal, data.gold, 3000); 
            setTimeout(() => {
                $('#playerGold').fadeOut(200);
            }, 9000);
        }
        
        if (data.hunger != undefined) {
            $('#hunger_bars').css("height", data.hunger * 1.59 + '%');
            if (data.hunger <= 100) {
                $('#hunger_bars').css("height", data.hunger * 1.59 + '%');
            }
        }

        if (data.thirst !== undefined) {
            $('#thirst_bars').css("height", data.thirst * 1.59 + '%');
            if (data.thirst <= 100) {
                $('#thirst_bars').css("height", data.thirst * 1.59 + '%');
            }
        }

        if (data.horseclean !== undefined) {
            var brightnessClean = 1;
            if (data.onHorse && data.horseclean < 75 && data.horseclean > 50) {
                brightnessClean = 85;
                $('.hud-holder').css('filter', 'brightness(0.' + brightnessClean + ')')
            } else if (data.onHorse && data.horseclean < 50 && data.horseclean > 25) {
                brightnessClean = 8;
                $('.hud-holder').css('filter', 'brightness(0.' + brightnessClean + ')')
            } else if (data.onHorse && data.horseclean < 25 && data.horseclean > 0) {
                brightnessClean = 75;
                $('.hud-holder').css('filter', 'brightness(0.' + brightnessClean + ')')
            } else {
                $('.hud-holder').css('filter', 'brightness(1)')
            }
        }


        if (data.stamina < staminaOldUpdate) {
            staminaOldUpdate = data.stamina;
            $('.hud-holder').css("transform", 'rotateY(-4deg)');
            $('.player-Hud, .player-HudNumber').css("filter", 'drop-shadow(0 0 0.2vh rgba(0, 0, 0, 0.5))');
            $('#player-Stamina').css('margin-top', '0.5vh');
            $('#player-Stamina').css("height", '0.4vh');
            $('#player-Stamina').addClass('decressanmisStamina');
        } else {
            $('.player-Hud, .player-HudNumber').css("filter", '');
            $('.hud-holder').css("transform", '');
            $('#player-Stamina').css('margin-top', '');
            $('#player-Stamina').css("height", '');
            $('#player-Stamina').removeClass('decressanmisStamina');
        }
        if (staminaOldUpdate < data.stamina) {
            staminaOldUpdate = data.stamina;
        }

        $('.DynamicMountStaminaBars').css("width", data.horsestamina + '%');
        $('.DynamicMountHealthBars').css("width", data.horsehealth + '%');
        if (data.horsestamina < horseStaminaOldUpdate) {
            horseStaminaOldUpdate = data.horsestamina;
            $('#player-mountStamina').css("height", '0.3vh');
        } else {
            $('#player-mountStamina').css("height", '');
        }
        if (horseStaminaOldUpdate < data.horsestamina) {
            horseStaminaOldUpdate = data.horsestamina;
        }

        if (data.horsehealth < horseHealthOldUpdate) {
            horseHealthOldUpdate = data.horsehealth;
            $('#player-mountHealth').css("height", '0.4vh');
        } else {
            $('#player-mountHealth').css("height", '');
        }
        if (horseHealthOldUpdate < data.horsehealth) {
            horseHealthOldUpdate = data.horsehealth;
        }

        if (data.stamina) {
            if (data.stamina < 110) {
                $('.playerDynamicStaminaBars').css("width", data.stamina + '%');
            }
            if (data.stamina < 25) {
                $('.playerDynamicStaminaBars').css("background", 'red');
            } else {
                $('.playerDynamicStaminaBars').css("background", '');
            }

            if (data.stamina < 20) {
                $('#player-Stamina').css("opacity", '0.5');

            } else {
                $('#player-Stamina').css("opacity", '');
            }
        }

        if (data.talking != undefined) {
            if (data.radio != undefined && data.radio == true) {
                $('.radio-wave').fadeIn(400).html(data.myradioWave + ' hz');
                $('.talking-stats').fadeOut(0);
                $('.mic-div').css('background', 'var(--radio-talk)');
                $('#mic-div').addClass('talking-waveAnmis1');
                $('#mic-div2').addClass('talking-waveAnmis2');
                $('#mic-div3').addClass('talking-waveAnmis3');
                $('.mic-div, .mic-divempty').css('width', '0.3vh');
                $('.mic-div, .mic-divempty').css('margin', '0.1vh');
            } else if (data.talking != undefined && data.talking == true) {
                $('.talking-stats').fadeIn(400);
                $('.radio-wave').fadeOut(0);
                $('#mic-div').addClass('talking-waveAnmis1');
                $('#mic-div2').addClass('talking-waveAnmis2');
                $('#mic-div3').addClass('talking-waveAnmis3');
                $('.mic-div').css('background', 'var(--server-color)');
                $('.mic-div, .mic-divempty').css('width', '0.3vh');
                $('.mic-div, .mic-divempty').css('margin', '0.1vh');
            } else {
                $('#mic-div').removeClass('talking-waveAnmis1');
                $('#mic-div2').removeClass('talking-waveAnmis2');
                $('#mic-div3').removeClass('talking-waveAnmis3');
                $('.talking-stats, .radio-wave').fadeOut(0);
                $('.mic-div').css('background', '');
                $('.mic-div, .mic-divempty').css('margin', '');
                $('.mic-div, .mic-divempty').css('width', '');
            }
        }

        if (data.onHorse) {
            $('#bottomBarsAnmis2, #bottomBarsAnmis3, .mountComp').fadeIn(500);
            $('.temp').html(data.temp);
            if (data.tempNum < 5) {
                $('.temp').css('color', 'var(--coldTemp)');
            } else if (data.tempNum >= 5 && data.tempNum < 25) {
                $('.temp').css('color', 'var(--normalTemp)');
            } else if (data.tempNum >= 25) {
                $('.temp').css('color', 'var(--hotTemp)');
            }
        } else {

            $('#bottomBarsAnmis2, #bottomBarsAnmis3, .mountComp').fadeOut(250);
        }
    };

    WHUD.UpdateProximity = function (data) {

        let state = 100;
        CurrentProx = data.voice;
        Currentstats = data.voice
        if (Currentstats === 1.5) {
            $('.talking-stats').html('Whisper');
        } else if (Currentstats === 3) {
            $('.talking-stats').html('Normal');
        } else if (Currentstats === 6) {
            $('.talking-stats').html('Shouting');
        }
        switch (data.voice) {
            case 1.5:
                state = 25;
                break;
            case 3:
                state = 50;
                break;
            case 6:
                state = 100;
                break;
            default:
                state = 100;
                break;
        }
        let whisper = document.getElementById("mic-div3");
        let normal = document.getElementById("mic-div2");
        let Shouting = document.getElementById("mic-div");
        if (whisper) whisper.style.visibility = state >= 25 ? 'visible' : 'hidden';
        if (normal) normal.style.visibility = state >= 50 ? 'visible' : 'hidden';
        if (Shouting) Shouting.style.visibility = state >= 100 ? 'visible' : 'hidden';
    };
    window.onload = function (e) {
        window.addEventListener("message", function (event) {
            switch (event.data.action) {
                case "hudtick":
                    WHUD.UpdateHud(event.data);
                    WHUD.UpdateProximity(event.data);
                    break;
                case "seatbelt":
                    WHUD.ToggleSeatbelt(event.data);
                    break;
                case "car":
                    WHUD.CarHud(event.data);
                    break;
            }
        });
    };
})();

