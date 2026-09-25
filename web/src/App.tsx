import { useCallback, useEffect, useRef, useState } from 'react';
import { VORP_CURRENCY_ICONS } from './vorpCurrencyIcons';
import WeaponWheel from './wheel/WeaponWheel';
import { post, setSoundBase } from './wheel/nui';
import { applyLocale, useI18n } from './i18n';
import { EditGrid, HudLayoutProvider, HudWidget, useNudge } from './settings/layout';
import { SettingsPanel } from './settings/SettingsPanel';
import { applyShape, applyTheme } from './settings/theme';
import { toTone } from './settings/palette';
import {
  FEATURE_WIDGETS, WIDGETS, cloneProfile, cloneSettings, decodeShare, defaultServer,
  defaultSettings, defaultWidget, homeX, isMotionFile, mergeServerCfg, mergeSettings,
  profileFrom, safeUrl,
  type GridCfg, type HudSettings, type MediaCfg, type MediaId, type ServerCfg,
  type ShapeCfg, type Theme, type WidgetCfg, type WidgetId, type WorldCfg,
} from './settings/types';

const clamp = (v: number, a: number, b: number) => Math.min(Math.max(v, a), b);

/* ⚠️ en-US always, never the player's locale.
   It used to format against 'ar-SA' whenever the HUD was in Arabic, and that locale
   renders Arabic-Indic digits: seventy-five came out as ٧٥, which at HUD size reads as
   the letters "Vo" and not as a number at all. The money and the level are quantities,
   and the digits everyone here reads quantities in are 0-9 -- the rest of the HUD stays
   Arabic. (The separator stays a comma for the same reason: it groups thousands.) */
const fmtInt = (n: number) => (Number(n) || 0).toLocaleString('en-US', { maximumFractionDigits: 0 });
/* Money is dollars and cents: 0.00, 1,250.50 - never a rounded whole. */
const fmtMoney = (n: number) => (Number(n) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/* -- icons (local SVG) -- */
/* ★ The core icons come from RDR's own art, not from my drawing.
   They are drawn as a mask (--ic-* from main.tsx) so they tint exactly like SVG icons. */
const TexIcon = ({ name }: { name: string }) => (
  <span className="tex-ic" style={{ ['--ic' as string]: `var(--ic-${name})` }} />
);

const HeartIcon = () => <TexIcon name="player_health" />;
/* ★ RDR's own heart, split -- not a heart drawn anew. The file is derived from
   player_health.png by carving a jagged crack through it and pushing the halves apart --
   so the silhouette stays the original verbatim and only the break is new. */
const BrokenHeartIcon = () => <TexIcon name="player_health_broken" />;
const MeatIcon = () => <TexIcon name="food" />;
const WaterIcon = () => <TexIcon name="drink" />;
const HorseIcon = () => <TexIcon name="horse_health" />;
const MicIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 0 0-6 0v5a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.9V21h2v-3.1A7 7 0 0 0 19 11h-2z"/></svg>);
/* The voice waves '))' -- each arc is its own element so it can ripple separately while speaking */
const WaveIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
    <path className="wv wv-1" d="M8 8.5a5.5 5.5 0 0 1 0 7" />
    <path className="wv wv-2" d="M12.5 5a10 10 0 0 1 0 14" />
    <path className="wv wv-3" d="M17 2a14.5 14.5 0 0 1 0 20" />
  </svg>
);

const BuffIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13 2 4 14h6l-1 8 9-12h-6l1-8z"/></svg>);
const BoltIcon = () => <TexIcon name="player_stamina" />;
/* Horse stamina -- a drawn horseshoe.
   ★ There is no original for it in the RDR art we have (w_lib holds player_stamina and
   horse_health only, no horse_stamina). And we did not reuse the player's lightning bolt:
   two adjacent bolts in the row read as one thing repeated. */
const HorseShoeIcon = () => (
  <svg viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 2C7.9 2 4.5 5.3 4.5 9.4c0 2.9 1.2 5 2.2 6.7.5.8.9 1.5 1.1 2.1.2.6.3 1.2.3 1.8H5.6v2h5.1v-1c0-1.3-.2-2.4-.6-3.4-.4-1-.9-1.8-1.4-2.6-.9-1.5-1.7-2.9-1.7-4.6a5 5 0 0 1 10 0c0 1.7-.8 3.1-1.7 4.6-.5.8-1 1.6-1.4 2.6-.4 1-.6 2.1-.6 3.4v1h5.1v-2h-2.5c0-.6.1-1.2.3-1.8.2-.6.6-1.3 1.1-2.1 1-1.7 2.2-3.8 2.2-6.7C19.5 5.3 16.1 2 12 2z" />
  </svg>
);
const CurrencyIcon = ({ type }: { type: keyof typeof VORP_CURRENCY_ICONS }) => (
  <img src={VORP_CURRENCY_ICONS[type]} alt="" aria-hidden="true" draggable={false} />
);
/* The bank. Drawn rather than bundled: neither vorp_core nor vorp_banking ships an
   icon for it, and a tinted copy of the cash note would read as cash twice over. */
const BankIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l10 5v2H2V7l10-5zm0 2.3L6.5 7h11L12 4.3zM4 10h2.5v7H4v-7zm5.2 0h2.5v7H9.2v-7zm5.3 0H17v7h-2.5v-7zM2 18h20v3H2v-3z"/></svg>);
const IdIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 5h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zm4.5 3A2.5 2.5 0 1 0 8.5 13 2.5 2.5 0 0 0 8.5 8zM4.6 17c.3-2 2-3.2 3.9-3.2s3.6 1.2 3.9 3.2H4.6zM14 8.5h6V10h-6V8.5zm0 3.5h6v1.5h-6V12zm0 3.5h4V17h-4v-1.5z"/></svg>);
const LevelIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2.9 6 6.6.6-5 4.4 1.5 6.4L12 16.6 6 19.4 7.5 13l-5-4.4L9.1 8z"/></svg>);
/* ★ The wallet's icons are drawn in one colour, like every other icon on this HUD. The
   coloured vorp PNGs (a green coin, a red bag, yellow bars) were the one thing in the
   top-right column that spoke another language; they stay bundled in vorpCurrencyIcons
   for the inventory, which still uses them. */
const CashIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M2 6h20v12H2V6zm2 2v8h16V8H4zm8 1a3 3 0 1 1 0 6 3 3 0 0 1 0-6zm0 1.6a1.4 1.4 0 1 0 0 2.8 1.4 1.4 0 0 0 0-2.8zM5 9.5h2v5H5v-5zm12 0h2v5h-2v-5z"/></svg>);
const DirtyIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 2h6l-1.2 2.4L15 6H9l1.2-1.6L9 2zm0 5h6c3.3 2.2 5 5.1 5 8.4 0 3.9-2.8 6.6-8 6.6s-8-2.7-8-6.6C4 12.1 5.7 9.2 9 7zm3 3.2c-1.9 0-3.1 1-3.1 2.4 0 1.2.8 1.9 2.5 2.2l.9.2c.9.2 1.2.4 1.2.8 0 .5-.5.8-1.4.8-1 0-1.6-.4-1.7-1H8.5c.1 1.5 1.2 2.5 3 2.7V19h1.2v-1.4c1.8-.2 2.9-1.2 2.9-2.6 0-1.3-.8-2-2.6-2.4l-.9-.2c-.8-.2-1.1-.4-1.1-.8 0-.4.4-.7 1.2-.7.8 0 1.3.3 1.4.9h1.9c-.1-1.4-1.1-2.3-2.8-2.5V8.9H12v1.3z"/></svg>);
const GoldIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7.2 4h9.6l2.2 5H5l2.2-5zm-4 7h8.6l2.2 5H1l2.2-5zm9.8 0h8.6l2.2 5H10.8l2.2-5zM3.2 18h8.6l2.2 5H1l2.2-5zm9.8 0h8.6l2.2 5H10.8l2.2-5z" transform="scale(.9) translate(1.3 -1)"/></svg>);
/* The level's medallion -- w_level's, small: a paper-silver ring, an ink disc, a star (the theme's neutral ink and paper). */
const LevelMedal = () => (
  <svg viewBox="0 0 40 40" aria-hidden="true">
    <defs>
      <linearGradient id="hud-medal-silver" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stopColor="#FFFFFF"/><stop offset=".3" stopColor="#BCBCBC"/><stop offset=".5" stopColor="#7A7A7A"/><stop offset=".72" stopColor="#CACACA"/><stop offset="1" stopColor="#858585"/>
      </linearGradient>
      <radialGradient id="hud-medal-disc" cx=".5" cy=".38" r=".72">
        <stop offset="0" stopColor="#333333"/><stop offset=".55" stopColor="#111111"/><stop offset="1" stopColor="#0A0A0A"/>
      </radialGradient>
    </defs>
    <circle cx="20" cy="20" r="18.5" fill="url(#hud-medal-silver)" stroke="#0A0A0A" strokeWidth=".8"/>
    <circle cx="20" cy="20" r="15" fill="url(#hud-medal-disc)" stroke="#F2F2F2" strokeWidth=".9" opacity=".95"/>
    <path d="M20 10.5l2.4 5 5.4.5-4.1 3.6 1.3 5.3-5-2.9-5 2.9 1.3-5.3-4.1-3.6 5.4-.5z" fill="#F2F2F2" stroke="#0A0A0A" strokeWidth=".4"/>
  </svg>
);
const PvpIcon = () => (<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l7 3v6c0 4.8-3.2 8.6-7 11-3.8-2.4-7-6.2-7-11V5l7-3zm0 3.2L7 6.9v4.1c0 3.4 2.1 6.3 5 8.2 2.9-1.9 5-4.8 5-8.2V6.9L12 5.2z"/></svg>);

/* -- ammo --
   The number = what is in this weapon's magazine alone · red = zero

   ★ The reserve (rounds beyond the clip) is shown after a separator, as the game does: "6 | 94".
   Lua omits it when the inventory keeps the belt out of the weapon (w_inventory), in which
   case only the clip is shown -- bag ammo is not in the weapon until it is chambered.

   ⚠️ The source is whatever Lua sends: w_inventory's export when that inventory runs, else the
   engine's own numbers (GET_AMMO_IN_CLIP / GET_AMMO_IN_PED_WEAPON) -- see client/ammo.lua. */
interface AmmoHand {
  slot: number; label: string; hand: number;
  loaded: number; capacity: number; active: boolean;
  /** Rounds beyond the clip -- the belt / the ped's pool. Shown after the clip, as the game does (6 | 94). */
  reserve?: number;
  /** The item name of the chambered ammo type -- its image is under imageBase (default w_inventory/web/images) */
  ammoItem?: string | null;
  /** nui://<resource>/<path>/ the ammo images are served from; Lua sets it per inventory */
  imageBase?: string;
}

/* A fallback when the type has no image: a drawn cartridge. */
const Cartridge = () => (
  <svg viewBox="0 0 32 32" aria-hidden="true">
    <circle cx="16" cy="16" r="14" className="cart-ring" />
    <circle cx="16" cy="16" r="9" className="cart-mid" />
    <circle cx="16" cy="16" r="4" className="cart-core" />
  </svg>
);

/* ★ The ammo type's image from the inventory itself.
   Every type has its own item and image there (ammorevolverexplosive.png and its siblings),
   so we build the path from the name and do not duplicate the images in w_hud. And if the
   image is missing we fall back to the drawn cartridge rather than a broken square. */
function AmmoIcon({ item, base }: { item?: string | null; base?: string }) {
  const [broken, setBroken] = useState(false);

  if (!item || broken) return <span className="ammo-cart"><Cartridge /></span>;

  return (
    <span className="ammo-cart">
      <img
        src={`${base || 'nui://w_inventory/web/images/'}${item}.png`}
        alt=""
        aria-hidden="true"
        draggable={false}
        onError={() => setBroken(true)}
      />
    </span>
  );
}

function AmmoRow({ hands }: { hands: AmmoHand[] }) {
  if (!hands.length) return null;

  return (
    <div className="ammo-row" dir="ltr">
      {hands.map((h) => (
        <div className={`ammo-item${h.active ? ' active' : ''}`} key={h.slot} title={h.label}>
          <span className={`ammo-clip${h.loaded <= 0 ? ' empty' : ''}`}>{h.loaded}</span>
          {h.reserve != null && (
            <span className="ammo-reserve">
              <span className="ammo-sep">|</span>
              <span className={`ammo-total${h.reserve <= 0 ? ' empty' : ''}`}>{h.reserve}</span>
            </span>
          )}
          <AmmoIcon item={h.ammoItem} base={h.imageBase} />
          {h.hand === 1 && <span className="ammo-offhand" />}
        </div>
      ))}
    </div>
  );
}

/* ════════════════════════════════════════════════════════════════════════════
   A picture from a link -- any kind of picture

   ★ One <img> covers every still and every animated image format the browser knows:
     PNG, JPEG, GIF, animated GIF, WebP, animated WebP, APNG, SVG. None of them needs
     to be named here, and a format added to Chromium next year works without us.

   ★ <video> is the only other tag needed, for the moving-picture files (mp4, webm).
     Muted and playsInline so it behaves like a picture rather than a player: no sound,
     no controls, and it starts on its own -- which the browser only allows *because*
     it is muted.

   ⚠️ A broken link draws nothing in the live HUD and a marked outline in the editor.
     Not a broken-image glyph and not an error: a picture that failed to load is a
     picture the player can see is missing, and the game underneath is worth more than
     a placeholder announcing our disappointment.
   ════════════════════════════════════════════════════════════════════════════ */
function HudMedia({ cfg, editing }: { cfg: MediaCfg; editing: boolean }) {
  const [failed, setFailed] = useState(false);

  /* A new link deserves a fresh attempt -- otherwise one bad URL poisons every later
     one, because `failed` would still be true after the player corrected it. */
  useEffect(() => { setFailed(false); }, [cfg.url]);

  const style = {
    width: `${cfg.width}rem`,
    height: cfg.height > 0 ? `${cfg.height}rem` : undefined,
  };

  if (cfg.url === '' || failed) {
    if (!editing) return null;
    return <span className={'hud-media-ph' + (failed ? ' is-bad' : '')} style={style} />;
  }

  if (isMotionFile(cfg.url)) {
    return (
      <video
        className="hud-media"
        style={style}
        src={cfg.url}
        autoPlay
        loop
        muted
        playsInline
        onError={() => setFailed(true)}
      />
    );
  }

  return (
    <img
      className="hud-media"
      style={style}
      src={cfg.url}
      alt=""
      draggable={false}
      onError={() => setFailed(true)}
    />
  );
}

const Bar = ({ value, low }: { value: number; low?: boolean }) => (
  <div className="bar"><div className={`bar-fill${low ? ' low' : ''}`} style={{ width: `${clamp(value, 0, 100)}%` }} /></div>
);

/* -- buff badges --
   ★ Told apart by their word, not by a hue: the HUD is white and black, so the colour
     Config.Buffs still sends is not drawn -- paper edge, paper glyph, paper fill (hud.css). */
interface BuffMeta { label: string; color?: string }

function BuffRow({ buffs, meta }: { buffs: Record<string, number>; meta: Record<string, BuffMeta> }) {
  const entries = Object.entries(buffs || {}).filter(([, v]) => (Number(v) || 0) > 0);
  if (!entries.length) return null;

  return (
    <div className="buff-row">
      {entries.map(([kind, value]) => {
        const m = meta[kind] || { label: kind };
        return (
          <div className="buff-chip" key={kind} title={m.label}>
            <span className="buff-ic"><BuffIcon /></span>
            <span className="buff-body">
              <span className="buff-label">{m.label}</span>
              <span className="buff-bar">
                <span className="buff-fill"
                  style={{ width: `${clamp(Number(value) || 0, 0, 100)}%` }} />
              </span>
            </span>
          </div>
        );
      })}
    </div>
  );
}

/* -- the state core --
   ★ One element for every need: the same size and the same structure, and no two differ
     except in icon and colour. We tried bars, plates and three other styles, and every one
     of them mixed visual languages in a single panel. The game itself shows its states as
     circular cores -- so we follow it rather than invent.

   The structure: an outer ring that is the gauge (360 degrees draining from the top) and a
   dark disc with RDR grain in the middle, with the icon over it. */
type CoreState = 'ok' | 'warn' | 'danger';

function Core({ value, icon, brokenIcon, color, state, title, split = true, goldRing, goldIcon,
  poisoned, poisonRatio = 1 }: {
  value: number; icon: React.ReactNode; brokenIcon?: React.ReactNode;
  color?: string; state?: CoreState; title?: string; split?: boolean;
  goldRing?: boolean; goldIcon?: boolean;
  /** مسموم: حلقة القلب تخفت ويتصاعد منه دخانٌ عفن */
  poisoned?: boolean; poisonRatio?: number;
}) {
  const R = 44, C = 2 * Math.PI * R;
  const full = clamp(Number(value) || 0, 0, 100);

  /* ★ The two stages are derived from **one value**, with the halfway point between them:
       100..50  the ring drains and the icon is full
        50..0   the ring is empty and the icon drains

     We used to take the ring from the bar and the icon from a separate core
     (GetAttributeCoreValue), and the behaviour then differed between cores:

       · Health: the bar reaching zero = **death**. So the second stage was never seen and
         the icon never drained at all -- the player dies as the ring empties in one go.
       · Hunger and thirst: they have no core at all, so the icon snapped off at zero with
         no gradation.
       · Stamina alone worked in two stages -- so it looked like the odd one out.

     Deriving from one value made the behaviour identical for all of them, and more importantly
     health now crosses both stages before death: at 50% the ring is empty and the icon full,
     then the icon drains to zero -- and death is there, not before. */
  const ringLeft = split ? (full >= 50 ? (full - 50) * 2 : 0) : full;
  const v = ringLeft / 100;
  /* ★ The second system: the icon is itself a gauge.
     In RDR every need has two values -- the outer ring (the bar) and the inner core. So we
     draw the icon twice: dim and whole, and over it lit and clipped from the top by however
     much has drained. And whatever has no core follows its ring. */
  /* ★ The two systems run in sequence, not in parallel.
     As long as the ring holds anything the icon is **full**; it only begins to drain once
     the ring is completely empty. That is RDR's order: the bar first, then the core.

     I used to have the icon follow the core directly (core ?? value), so it drained while the
     ring was still half full -- and the player saw two gauges moving together for no reason,
     which is what showed up on food. */
  const cv = split ? (full >= 50 ? 100 : full * 2) : 100;

  /* ★ The break happens at danger alone, not at the first loss. In RDR the heart does not
     split until its owner is close to the end, and had it broken early the signal would lose
     its meaning: one picture accompanying you half the game and warning of nothing. So it
     goes with the red, never ahead of it. */
  const face = state === 'danger' && brokenIcon ? brokenIcon : icon;

  return (
    /* ★ Two degrees of gilding, not one: the item that gilds the ring alone is a half
       gilding, and the one that gilds the icon with it is a full one. Which is exactly
       what the goldHealthOuter / goldHealthInner pair says. */
    /* ★ التسمُّم يعلو على لون التحذير، والأحمر وحده يعلو عليه: الهود أبيض وأسود،
       فالسمّ يُقرأ بدخانه ونبضه لا بلونه، والأحمر علامة الخطر فلا يُخفيه شيء.
       الترتيب في hud.css يضمن ذلك. */
    <div className={'core'
        + (state && state !== 'ok' ? ' ' + state : '')
        + (goldRing ? ' gold-ring' : '')
        + (goldIcon ? ' gold-icon' : '')
        + (poisoned ? ' poisoned' : '')} title={title}>
      <svg className="core-ring-svg" viewBox="0 0 100 100">
        <circle className="core-track" cx="50" cy="50" r={R} />
        <circle className="core-ring" cx="50" cy="50" r={R}
          strokeDasharray={(C * v) + ' ' + C}
          style={color ? { stroke: color } : undefined} />
      </svg>
      {/* ★ The colour is on the disc rather than the ring alone: the icon inherits it through
          currentColor and so matches its ring without passing the colour twice. */}
      <span className="core-disc" style={color ? { color } : undefined}>
        <span className="core-ic">
          <span className="core-ic-dim">{face}</span>
          <span className="core-ic-lit" style={{ clipPath: `inset(${100 - cv}% 0 0 0)` }}>{face}</span>

          {/* ★ ثلاث خصلاتٍ لا واحدة: خصلةٌ واحدة تُقرأ فقاعةً صاعدة، والثلاث
              بتأخيرٍ مختلفٍ تُقرأ دخاناً. وشدّتها تتبع ما بقي من السمّ فتخفت
              وحدها قبل أن تنقطع — فلا يختفي الدخان دفعةً بلا مقدّمة. */}
          {poisoned && (
            <span className="core-fumes" aria-hidden="true"
              style={{ opacity: 0.35 + 0.65 * Math.max(0, Math.min(1, poisonRatio)) }}>
              <i /><i /><i />
            </span>
          )}
        </span>
      </span>
    </div>
  );
}
/* -- the compass -- */
const CARDS = [
  { a: 0, l: 'compass.n', major: true }, { a: 45, l: 'compass.ne' },
  { a: 90, l: 'compass.e', major: true }, { a: 135, l: 'compass.se' },
  { a: 180, l: 'compass.s', major: true }, { a: 225, l: 'compass.sw' },
  { a: 270, l: 'compass.w', major: true }, { a: 315, l: 'compass.nw' },
];
/* The eight names when the dictionary sent by Lua lacks them (an old locales file): the
   Arabic and English cards, so the compass never prints "COMPASS.E". */
const CARD_FALLBACK: Record<string, { ar: string; en: string }> = {
  'compass.n': { ar: 'ش', en: 'N' }, 'compass.ne': { ar: 'ش ق', en: 'NE' },
  'compass.e': { ar: 'ق', en: 'E' }, 'compass.se': { ar: 'ج ق', en: 'SE' },
  'compass.s': { ar: 'ج', en: 'S' }, 'compass.sw': { ar: 'ج غ', en: 'SW' },
  'compass.w': { ar: 'غ', en: 'W' }, 'compass.nw': { ar: 'ش غ', en: 'NW' },
};
const sdiff = (a: number, h: number) => ((a - h + 540) % 360) - 180;
const WIN = 62;                 // the visible window, +/-62 degrees
const HALF = 27;                // half the compass width (rem) -- matches a 54rem width
const PPD = HALF / WIN;         // rem per degree

function Compass({ heading }: { heading: number }) {
  const { t, lang } = useI18n();
  const card = (key: string) => {
    const v = t(key);
    return v === key ? (CARD_FALLBACK[key]?.[lang] ?? key) : v;
  };
  const ticks: number[] = [];
  for (let t = 0; t < 360; t += 15) { const d = sdiff(t, heading); if (Math.abs(d) <= WIN) ticks.push(t); }
  return (
    <div className="compass">
      <div className="compass-line" />
      {ticks.map((t) => {
        const d = sdiff(t, heading);
        return <div key={`t${t}`} className="compass-tick" style={{ left: `${HALF + d * PPD}rem` }} />;
      })}
      {CARDS.map((c) => {
        const d = sdiff(c.a, heading);
        if (Math.abs(d) > WIN) return null;
        return (
          <div key={c.a} className={`compass-card${c.major ? '' : ' minor'}`} style={{ left: `${HALF + d * PPD}rem` }}>
            {card(c.l)}
          </div>
        );
      })}
      <div className="compass-marker" />
    </div>
  );
}

interface Hud {
  show: boolean; health: number; hunger: number; thirst: number; stamina: number;
  cash: number; gold: number; bank: number; dirty: number;
  talking: boolean;
  healthCore: number; staminaCore: number;
  /* ★ Which parts are gilded right now. Absent = nothing is -- see client/consumables.lua. */
  gilded?: { healthRing?: boolean; healthIcon?: boolean; staminaRing?: boolean; staminaIcon?: boolean };
  /* ★ التسمُّم — غائبٌ ما دام اللاعب سليماً. left ثوانٍ باقية، وratio نسبتها. */
  poisoned?: { active?: boolean; left?: number; ratio?: number };
  horsehealthCore: number; horsestaminaCore: number;
  voice: number; voiceLevel: number; voiceLevels: number;
  onHorse: boolean; horsehealth: number; horsestamina: number;
  cleanliness: number; buffs: Record<string, number>;
}
const DEFAULT: Hud = {
  show: false, health: 100, hunger: 100, thirst: 100, stamina: 100,
  cash: 0, gold: 0, bank: 0, dirty: 0, talking: false,
  voice: 3, voiceLevel: 2, voiceLevels: 4,
  onHorse: false, horsehealth: 100, horsestamina: 100,
  healthCore: 100, staminaCore: 100, horsehealthCore: 100, horsestaminaCore: 100,
  cleanliness: 100, buffs: {},
};

/* Per-element display settings -- they arrive from Lua (Config.Display) in the setDisplay message
   label: a caption under the circle. ★ Required for every conditional circle: conditionals come
   and go, so the fourth circle's position may be one thing once and another the next -- and
   without a name under it the player reads the icons as 'swapping around'. */
/* State colour thresholds -- they arrive from Config.Thresholds.
   ★ All of our needs drain, so two thresholds are enough. (There used to be warnHigh/dangerHigh
   for needs that filled -- they went with the stress, toxicity, bladder and bowel systems.) */
interface Thresholds { warnLow?: number; dangerLow?: number }
const DEFAULT_THRESHOLDS: Thresholds = { warnLow: 40, dangerLow: 20 };

interface DisplayCfg {
  show?: boolean; color?: string; alwaysOn?: boolean; label?: boolean;
  /** Fills up: show on rising to this value */
  showAt?: number;
  /** Drains (health/food/water/stamina): show on falling to this value */
  showBelow?: number;
}

/* A safe assumption before setDisplay arrives: the essentials visible and the rest on demand */
const DEFAULT_DISPLAY: Record<string, DisplayCfg> = {
  health: { show: true, alwaysOn: false, showBelow: 50 },
  hunger: { show: true, alwaysOn: false, showBelow: 50 },
  thirst: { show: true, alwaysOn: false, showBelow: 50 },
  stamina: { show: true, alwaysOn: false, showBelow: 50 },

  horse: { show: true, alwaysOn: true },
  buffs: { show: true, alwaysOn: false },
};

/* Is this element shown at its current value?
   ★ Two directions, not one: health and food warn on the way down, while filling needs warn on
     the way up. So one measure is not enough -- showBelow for the first and showAt for the second. */
const shown = (cfg: DisplayCfg | undefined, value: number) => {
  if (!cfg || cfg.show === false) return false;
  if (cfg.alwaysOn) return true;

  const v = Number(value) || 0;

  if (cfg.showBelow != null) return v <= cfg.showBelow;
  return v >= (cfg.showAt ?? 1);
};

/* The captions under the circles and the PVP words are dictionary keys (ui.hud.*) --
   see i18n.ts; nothing is written here in either language. */

/* ════════════════════════════════════════════════════════════════════════════
   Sample content for the editor
   ★ Half the HUD is conditional -- ammo appears when armed, the horse circles while
     mounted, the effects while an effect runs. Laying out a HUD you can only see one
     third of is not laying it out. So while the panel is open every widget is drawn,
     with a stand-in where there is nothing real to show, and the stand-in never leaks
     into the live HUD: it is read from `editing` alone.
   ════════════════════════════════════════════════════════════════════════════ */
const DEMO_AMMO: AmmoHand[] = [
  { slot: 1, label: 'sample', hand: 0, loaded: 6, capacity: 6, reserve: 94, active: true, ammoItem: null },
];

function App() {
  const [hud, setHud] = useState<Hud>(DEFAULT);
  const [heading, setHeading] = useState(0);
  const [server, setServer] = useState('REDM RP');
  const [pid, setPid] = useState('');
  const [location, setLocation] = useState('');
  const { t } = useI18n();
  /* ★ tokens and xp may be null: VORP has them and RSG does not. And the difference between
     null and zero is the difference between 'this currency does not exist' and 'your balance
     is zero' -- a line saying zero tokens on an RSG server is a falsehood. */
  type Econ = { tokens: number | null; gold: number; cash: number; dirty: number | null; bank: number | null;
                xp: number | null; level: number | null; id: string; has: boolean };
  const [econ, setEcon] = useState<Econ>({ tokens: null, gold: 0, cash: 0, dirty: null, bank: null,
                                           xp: null, level: null, id: '', has: false });
  const [pvp, setPvp] = useState<boolean | null>(null);
  const [ammo, setAmmo] = useState<AmmoHand[]>([]);
  const [companion,setCompanion]=useState<null|{name:string;health:number;hunger:number;thirst:number;needsWater?:boolean;mode:string;dead:boolean;distance:number}>(null);
  const [display, setDisplay] = useState<Record<string, DisplayCfg>>(DEFAULT_DISPLAY);
  const [buffMeta, setBuffMeta] = useState<Record<string, BuffMeta>>({});
  const [thr, setThr] = useState<Thresholds>(DEFAULT_THRESHOLDS);
  /* Preview: shows every core at once regardless of thresholds (/hudall) */
  const [preview, setPreview] = useState(false);
  const headRef = useRef(0);

  /* ── the player's own settings ────────────────────────────────────────────── */
  const [settings, setSettings] = useState<HudSettings>(defaultSettings);
  /* The server's half of the settings: what everyone gets, and only an admin may change. */
  const [srv, setSrv] = useState<ServerCfg>(defaultServer);
  const [isAdmin, setIsAdmin] = useState(false);
  const [srvState, setSrvState] = useState<'idle' | 'dirty' | 'saving' | 'saved'>('idle');
  const [editing, setEditing] = useState(false);
  const [selected, setSelected] = useState<WidgetId | null>(null);
  const [saving, setSaving] = useState<'idle' | 'dirty' | 'saving' | 'saved'>('idle');

  /* ⚠️ A ref beside the state: the autosave timer fires outside React's flow and must send
     the settings as they are at that instant, not as they were when the timer was armed. */
  const settingsRef = useRef(settings);
  settingsRef.current = settings;
  const saveTimer = useRef<number | null>(null);

  const flush = useCallback(() => {
    if (saveTimer.current !== null) { clearTimeout(saveTimer.current); saveTimer.current = null; }

    setSaving('saving');
    void post('hud:settings:save', { settings: settingsRef.current }).then(() => {
      setSaving('saved');
      window.setTimeout(() => setSaving((s) => (s === 'saved' ? 'idle' : s)), 1600);
    });
  }, []);

  /* Every edit is written down on its own after a pause -- a player who closes the game
     without pressing Save does not lose the layout they spent ten minutes on. The button
     stays because a save you cannot see happen is a save you do not trust. */
  const touch = useCallback(() => {
    setSaving('dirty');
    if (saveTimer.current !== null) clearTimeout(saveTimer.current);
    saveTimer.current = window.setTimeout(flush, 1400);
  }, [flush]);

  const patch = useCallback((id: WidgetId, p: Partial<WidgetCfg>) => {
    setSettings((s) => ({ ...s, widgets: { ...s.widgets, [id]: { ...s.widgets[id], ...p } } }));
    touch();
  }, [touch]);

  const setTheme = useCallback((t: Partial<Theme>) => {
    setSettings((s) => ({ ...s, theme: { ...s.theme, ...t } }));
    touch();
  }, [touch]);

  const setGrid = useCallback((g: Partial<GridCfg>) => {
    setSettings((s) => ({ ...s, grid: { ...s.grid, ...g } }));
    touch();
  }, [touch]);

  const setScale = useCallback((n: number) => {
    setSettings((s) => ({ ...s, scale: n }));
    touch();
  }, [touch]);

  const setShape = useCallback((patchShape: Partial<ShapeCfg>) => {
    setSettings((s) => ({ ...s, shape: { ...s.shape, ...patchShape } }));
    touch();
  }, [touch]);

  /* ★ The link is cleaned here rather than at the field, so nothing unsafe reaches the
     state at all -- not from the panel, not from a share code, not from a save. The
     panel keeps its own draft while the player types (see MediaFields) precisely
     because this rejects a half-typed URL, and it should. */
  const setMedia = useCallback((id: MediaId, patchMedia: Partial<MediaCfg>) => {
    const clean: Partial<MediaCfg> = { ...patchMedia };
    if (clean.url !== undefined) clean.url = safeUrl(clean.url);

    setSettings((s) => ({ ...s, media: { ...s.media, [id]: { ...s.media[id], ...clean } } }));
    touch();
  }, [touch]);

  const setWorld = useCallback((patchWorld: Partial<WorldCfg>) => {
    setSettings((s) => ({ ...s, world: { ...s.world, ...patchWorld } }));
    touch();
  }, [touch]);

  /* -- saved layouts ---------------------------------------------------------
     A layout captures the look and nothing else: colours, sizes, positions, shape.
     Not the grid step, not where the panel was left, not the minimap choice --
     those are how you *work*, and switching from a combat layout to a screenshot
     one should not drag your workbench along with it. */
  const saveProfile = useCallback((slot: number, name: string) => {
    setSettings((s) => {
      const profiles = s.profiles.slice();
      profiles[slot] = profileFrom(s, name);
      return { ...s, profiles };
    });
    touch();
  }, [touch]);

  const applyProfile = useCallback((slot: number) => {
    setSettings((s) => {
      const saved = s.profiles[slot];
      if (!saved) return s;

      const copy = cloneProfile(saved);
      return { ...s, theme: copy.theme, scale: copy.scale, shape: copy.shape, widgets: copy.widgets };
    });
    touch();
  }, [touch]);

  const clearProfile = useCallback((slot: number) => {
    setSettings((s) => {
      const profiles = s.profiles.slice();
      profiles[slot] = null;
      return { ...s, profiles };
    });
    touch();
  }, [touch]);

  /* ── the server's settings ───────────────────────────────────────────────────
     ★ Applied here the instant they are touched, and sent to the server a moment after
       the admin stops touching them.

       They used to be a draft behind a Save button, on the reasoning that a slider
       changing what everyone sees, live, is not a slider anyone should be holding. That
       reasoning was about the *broadcast*, and it quietly cost the admin the thing they
       needed most: seeing their own change. Somebody pasting a logo link has no way to
       judge the size without watching it, and being told to press Save first and undo
       afterwards is not a way to judge anything.

       So the two are separated. The edit is local and immediate -- the admin sees it on
       their own screen at once. The publish is debounced and reaches everybody once the
       adjusting has stopped. Nobody else watches a slider being dragged.

     ⚠️ Through a ref, because the timer fires outside React's flow and must send what is
       current at that instant, not what was current when it was armed. */
  const srvRef = useRef(srv);
  srvRef.current = srv;
  const srvTimer = useRef<number | null>(null);

  const publishServer = useCallback(() => {
    if (srvTimer.current !== null) { clearTimeout(srvTimer.current); srvTimer.current = null; }

    setSrvState('saving');
    void post('hud:admin:save', { cfg: srvRef.current }).then(() => {
      setSrvState('saved');
      window.setTimeout(() => setSrvState((s) => (s === 'saved' ? 'idle' : s)), 1800);
    });
  }, []);

  const editServer = useCallback((fn: (c: ServerCfg) => ServerCfg) => {
    setSrv(fn);
    setSrvState('dirty');

    if (srvTimer.current !== null) clearTimeout(srvTimer.current);
    srvTimer.current = window.setTimeout(publishServer, 900);
  }, [publishServer]);

  /** Returns whether the code could be read -- the panel says so either way. */
  const importCode = useCallback((code: string): boolean => {
    const incoming = decodeShare(code);
    if (!incoming) return false;

    setSettings((s) => ({
      ...s,
      theme: incoming.theme,
      scale: incoming.scale,
      shape: incoming.shape,
      widgets: incoming.widgets,
    }));
    touch();
    return true;
  }, [touch]);

  const setPanelPos = useCallback((x: number, y: number) => {
    setSettings((s) => ({ ...s, panel: { x, y } }));
    touch();
  }, [touch]);

  const resetWidget = useCallback((id: WidgetId) => {
    setSettings((s) => {
      const meta = WIDGETS.find((w) => w.id === id);
      if (!meta) return s;
      return { ...s, widgets: { ...s.widgets, [id]: defaultWidget(meta) } };
    });
    touch();
  }, [touch]);

  const resetPositions = useCallback(() => {
    setSettings((s) => {
      const next = cloneSettings(s);
      /* homeX, not meta.home.x. The circles' default is written in vh -- they were
         anchored beside the minimap, which is sized by the height -- so restoring
         them means converting against the screen actually in front of the player. */
      for (const meta of WIDGETS) {
        next.widgets[meta.id].x = homeX(meta);
        next.widgets[meta.id].y = meta.home.y;
      }
      return next;
    });
    touch();
  }, [touch]);

  const resetAll = useCallback(() => {
    setSettings(defaultSettings());
    setSelected(null);
    touch();
  }, [touch]);

  const closeMenu = useCallback(() => {
    setEditing(false);
    setSelected(null);
    flush();
    void post('hud:settings:close', {});
  }, [flush]);

  /* The palette reaches the stylesheet, never the components: hud.css already draws
     everything from these variables, so a colour set here is a colour everywhere. */
  useEffect(() => { applyTheme(settings.theme); }, [settings.theme]);
  useEffect(() => { applyShape(settings.shape); }, [settings.shape]);

  /* The one setting that is not the UI's to apply: the minimap belongs to the engine,
     so it goes back to Lua. Sent on change and once on mount -- and 'server' means Lua
     leaves Config.OnFootMinimap and its siblings exactly as the server wrote them. */
  useEffect(() => { void post('hud:world', settings.world); }, [settings.world]);

  useNudge(editing, selected, settings, patch);

  /* Escape closes the panel. Registered in the capture phase so it is answered before
     anything else in the page decides Escape meant something to it. */
  useEffect(() => {
    if (!editing) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;

      /* ⚠️ An open colour picker owns Escape first. Both listeners sit on `window` in the
         capture phase, and stopPropagation does not silence a sibling on the same target --
         so the picker cannot defend itself here and the check has to be on this side.
         Without it, reaching for Escape to dismiss a picker closed the whole panel. */
      if (document.querySelector('.hs-picker')) return;

      e.preventDefault();
      e.stopPropagation();
      closeMenu();
    };

    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [editing, closeMenu]);

  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      const d: any = e.data || {};
      /* The language, the direction and every string the page shows -- from Lua, which
         asks the library. Once on mount (answered to w_hud:ready) and on every switch. */
      if (d.action === 'setLocale') { applyLocale(d); return; }
      if (d.action === 'companion') {
        setCompanion(d.pet && typeof d.pet === 'object' && !Array.isArray(d.pet) ? d.pet : null);
        return;
      }
      if (d.action === 'setServerInfo') {
        if (d.name != null) setServer(String(d.name));
        if (d.id != null) setPid(String(d.id));
        return;
      }
      if (d.action === 'setLocation') { setLocation(String(d.location || '')); return; }
      /* fwInfo/fwPvp are framework-neutral names. The old vorpInfo/vorpPvp are still accepted:
         external scripts may broadcast them straight into our UI. */
      if (d.action === 'fwInfo' || d.action === 'vorpInfo') {
        const num = (v: unknown) => (v == null ? null : Number(v) || 0);
        /* A merge for the pair that does not travel with every message: vorp:updateUi
           carries the dirty money but never the bank, so overwriting it with null on
           each currency change would blank the balance a second after it arrived. */
        setEcon((p) => ({
          tokens: num(d.tokens), gold: Number(d.gold) || 0, cash: Number(d.cash) || 0,
          dirty: d.dirty != null ? Number(d.dirty) || 0 : p.dirty,
          bank: d.bank != null ? Number(d.bank) || 0 : p.bank,
          xp: num(d.xp), level: d.level != null ? Number(d.level) || 0 : p.level,
          id: d.id != null ? String(d.id) : '', has: true,
        }));
        return;
      }
      /* ★ The level is w_level's (client/framework.lua reads its state bag), sent on its own
         the moment it changes -- a level-up shows here at once, not at the next purchase. */
      if (d.action === 'fwLevel') { setEcon((p) => ({ ...p, level: d.level == null ? null : Number(d.level) || 0 })); return; }
      if (d.action === 'fwPvp' || d.action === 'vorpPvp') { setPvp(!!d.pvp); return; }
      if (d.action === 'ammo') { setAmmo(Array.isArray(d.hands) ? d.hands : []); return; }
      if (d.action === 'setPreview') { setPreview(!!d.on); return; }

      /* ── the settings panel ─────────────────────────────────────────────── */
      if (d.action === 'hud:settings') {
        if (d.sounds) setSoundBase(String(d.sounds));
        /* ⚠️ Through mergeSettings without exception, even from our own Lua: what comes back
           has been through a database and a JSON round trip, and one bad number is a widget
           the player cannot find again. */
        setSettings(mergeSettings(d.settings));
        if (d.open === true) setEditing(true);
        setSaving('idle');
        return;
      }
      /* ── the server's settings, pushed to everyone ───────────────────────── */
      if (d.action === 'hud:server') {
        setSrv(mergeServerCfg(d.cfg));
        /* ⚠️ Only when it is stated. The admin flag arrives once, with the bootstrap;
           the later broadcasts that follow another admin's save do not carry it, and
           reading a missing field as false would quietly demote whoever is editing. */
        if (d.isAdmin !== undefined) setIsAdmin(!!d.isAdmin);
        return;
      }

      if (d.action === 'hud:menu') {
        const open = !!d.open;
        setEditing(open);
        if (!open) setSelected(null);
        return;
      }

      if (d.action === 'setDisplay') {
        // A merge, not a replacement: the player panel may send a single key only
        if (d.display && typeof d.display === 'object') {
          setDisplay((p) => ({ ...p, ...d.display }));
        }
        if (d.buffMeta && typeof d.buffMeta === 'object') setBuffMeta(d.buffMeta);
        if (d.thresholds && typeof d.thresholds === 'object') {
          setThr((p) => ({ ...p, ...d.thresholds }));
        }
        return;
      }
      if (d.comp === 'setCompassDirection') {
        // A light smoothing for the compass
        const target = Number(d.compassDirection) || 0;
        headRef.current = target;
        setHeading(target);
        return;
      }
      if (d.action === 'hudtick') {
        setHud((p) => ({
          show: d.show !== false,
          health: d.health ?? p.health, hunger: d.hunger ?? p.hunger,
          thirst: d.thirst ?? p.thirst, stamina: d.stamina ?? p.stamina,
          cash: d.cash ?? p.cash, gold: d.gold ?? p.gold,
          bank: d.bank ?? p.bank, dirty: d.dirty ?? p.dirty,
          talking: d.talking ?? p.talking, voice: d.voice ?? p.voice,
          voiceLevel: d.voiceLevel ?? p.voiceLevel, voiceLevels: d.voiceLevels ?? p.voiceLevels,
          onHorse: d.onHorse ?? p.onHorse,
          horsehealth: d.horsehealth ?? p.horsehealth, horsestamina: d.horsestamina ?? p.horsestamina,
          healthCore: d.healthCore ?? p.healthCore, staminaCore: d.staminaCore ?? p.staminaCore,
          /* ★ Assigned, not merged: Lua sends nil the moment the gilding ends, and ?? would
             keep the last state forever -- a core gilded for the rest of the session. */
          gilded: d.gilded,
          /* ★ إسنادٌ كذلك لا ‎??‎: لحظةَ ينتهي السمّ يُرسل Lua قيمةً غائبة،
             و‎??‎ كانت تُبقي القلب مسموماً إلى آخر الجلسة. */
          poisoned: d.poisoned,
          horsehealthCore: d.horsehealthCore ?? p.horsehealthCore,
          horsestaminaCore: d.horsestaminaCore ?? p.horsestaminaCore,
          cleanliness: d.cleanliness ?? p.cleanliness,
          buffs: d.buffs ?? p.buffs,
        }));
      }
    };
    window.addEventListener('message', onMsg);

    /* Tell Lua the page is up: it answers with the language and the server identity. */
    void post('w_hud:ready', {});

    return () => window.removeEventListener('message', onMsg);
  }, []);

  const visible = hud.show !== false;
  const active = hud.talking;
  // ★ The fill is the level as a proportion of its maximum -- not a fixed scale of five as before.
  //   The source is client/voice.lua, and the number of levels comes from the config so it follows automatically.
  const voiceFill = clamp((hud.voiceLevel / Math.max(1, hud.voiceLevels)) * 100, 0, 100);
  /* ★ The colour follows the **core**, not the ring.
     The ring (the bar) empties and fills on every sprint, so had the warning followed it the
     display would turn red dozens of times a minute and lose its meaning. The core, by contrast,
     only drains when you are genuinely in a bad way -- and that is the real warning.

     The colour state is computed here once rather than on every call:
     and each direction has its own two thresholds. Mixing them made an empty bladder read as 'danger'. */
  /* ★ One wrapper over shown: the preview bypasses the thresholds and the show flags together,
     so the preview condition is not repeated in ten places. */
  const showAll = preview || editing;

  /* The player's rule outranks the server's, and 'auto' is how they say they have no
     rule of their own -- which is not the same as saying 'always'. So the server's
     Config.Display keeps its say until someone deliberately takes it away. */
  const vis = (id: WidgetId, cfg: DisplayCfg | undefined, v: number): boolean => {
    if (showAll) return true;

    const w = settings.widgets[id];
    if (w.visibility === 'always') return true;
    if (w.visibility === 'below') return (Number(v) || 0) <= w.showBelow;

    return shown(cfg, v);
  };

  /* The two warning lines are the player's if they set them and the server's otherwise,
     and they are per widget because the needs do not warn at the same point: hunger at
     40 is a nuisance and health at 40 is an emergency. One shared pair has to be wrong
     for one of them. */
  const st = (id: WidgetId, v: number): CoreState => {
    const w = settings.widgets[id];
    const danger = w.danger ?? thr.dangerLow ?? 20;
    const warn = w.warn ?? thr.warnLow ?? 40;

    return v <= danger ? 'danger' : v <= warn ? 'warn' : 'ok';
  };

  /* The player's colour wins over the server's, and the server's over none. A colour the
     player never chose is `null` -- not white -- so Config.Display keeps its say until then.
     ★ Either is drawn as the nearest ink/paper tone (settings/palette.ts): the HUD is white and
       black, and a colour saved by an older build stays in the save, only its paint changes. */
  const tint = (id: WidgetId, fallback?: string): string | undefined => {
    const c = settings.widgets[id].color ?? fallback;
    return c ? toTone(c) : undefined;
  };

  // Top-right info -- from VORP if available, otherwise from hudtick
  const gold = econ.has ? econ.gold : hud.gold;
  const cash = econ.has ? econ.cash : hud.cash;
  /* ★ Per figure, not per source. econ.has says the framework panel has spoken at all;
     it does not promise this particular number came with it. The bank never travels in
     vorp:updateUi, so tying it to econ.has alone would show a zero over a real balance. */
  const bank = econ.bank ?? hud.bank;
  const dirty = econ.dirty ?? hud.dirty;
  const idVal = econ.has && econ.id ? econ.id : pid;
  /* ★ w_level's level when it runs; the old reading (vorp's xp in thousands) only as a
     stand-in on a server without it -- on this one it printed 0 next to a level-100 player. */
  const level = econ.level ?? (econ.xp == null ? null : Math.floor(econ.xp / 1000));

  /* Stand-ins, only while the panel is open (see the note above DEMO_AMMO). */
  const ammoShown = editing && ammo.length === 0 ? DEMO_AMMO : ammo;
  /* ★ No stand-in for the effects.
     There used to be two invented chips here so the block could be placed while nothing
     was running. They read as real effects nobody could account for, and the first
     question anyone asked on seeing them was what they were -- which is the whole case
     against them. The empty widget is still placeable: .hw-edit carries a minimum size,
     so what you drag is its outline and its name. */
  const locationShown = editing && location === '' ? t('hud.demoLocation') : location;
  const pvpShown = editing && pvp === null ? false : pvp;
  const idShown = editing && idVal === '' ? '1' : idVal;
  const levelShown = editing && level === null ? 0 : level;

  /* Every widget a switched-off feature takes with it, gathered once per render. */
  const disabled = new Set<WidgetId>();
  for (const [feature, ids] of Object.entries(FEATURE_WIDGETS)) {
    if (srv.features[feature as keyof typeof srv.features] === false) {
      for (const id of ids ?? []) disabled.add(id);
    }
  }

  const layout = { settings, editing, selected, select: setSelected, patch, disabled };

  /* ── the server's name-and-logo block ────────────────────────────────────────
     Its placement comes from the server, not from this player's layout, so it is fed
     to the widget as an override. An admin may drag it -- and that drag reaches every
     screen. Anyone else gets it exactly where the admin left it, and cannot pick it up. */
  const identityCfg: WidgetCfg = {
    ...settings.widgets.server,
    x: srv.identity.x,
    y: srv.identity.y,
    scale: srv.identity.scale,
    opacity: srv.identity.opacity,
    show: true,
    locked: false,
  };

  const identityPatch = isAdmin
    ? (p: Partial<WidgetCfg>) => editServer((c) => ({
        ...c,
        identity: {
          x: p.x ?? c.identity.x,
          y: p.y ?? c.identity.y,
          scale: p.scale ?? c.identity.scale,
          opacity: p.opacity ?? c.identity.opacity,
        },
      }))
    : undefined;

  return (
    <>
    {/* ★ Outside .hud-root deliberately: that container is pointer-events:none and its opacity
        is tied to the HUD state, while the wheel needs a mouse and shows even if the HUD is hidden. */}
    <WeaponWheel />

    <div className={`hud-root ${visible || editing ? 'visible' : ''}${editing ? ' editing' : ''}`}>
      {/* A shared paper gradient for the circles (the theme's paper, dimmed to lit) */}
      <svg width="0" height="0" style={{ position: 'absolute' }}>
        <defs>
          <linearGradient id="goldGrad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#7A7A7A" />
            <stop offset="50%" stopColor="#B4B4B4" />
            <stop offset="100%" stopColor="#F2F2F2" />
          </linearGradient>
        </defs>
      </svg>

      {editing && (
        <>
          {settings.grid.snap && <EditGrid step={settings.grid.size} />}
          {/* Bare screen clears the selection -- so nothing stays selected by accident. */}
          <div className="hw-canvas" onPointerDown={() => setSelected(null)} />
        </>
      )}

      <HudLayoutProvider value={layout}>
        {/* Only the confirmed active pet is live. The editor alone provides a
            labelled preview so players can arrange these cores without summoning. */}
        {(companion || editing) && ([
          { id: 'companionHealth', need: 'health', icon: <HeartIcon />, brokenIcon: <BrokenHeartIcon /> },
          { id: 'companionHunger', need: 'hunger', icon: <MeatIcon />, brokenIcon: undefined },
          { id: 'companionThirst', need: 'thirst', icon: <WaterIcon />, brokenIcon: undefined },
        ] as const).map(({ id, need, icon, brokenIcon }) => {
          if (need === 'thirst' && companion?.needsWater === false && !editing) return null;
          const value = clamp(Number(companion ? (need === 'health' && companion.dead ? 0 : companion[need]) : 100) || 0, 0, 100);
          if (!vis(id, { show: true, alwaysOn: true }, value)) return null;
          const status = companion ? t(companion.dead ? 'pet.injured' : companion.mode === 'stay' ? 'pet.stay' : 'pet.follow') : t('pet.preview');
          const title = `${companion?.name || t('widget.companion')} · ${t('pet.' + need)}: ${Math.round(value)}% · ${status}`;
          return <HudWidget id={id} key={id} className="companion-core">
            <Core value={value} icon={icon} brokenIcon={brokenIcon} title={title}
              color={tint(id)} state={st(id, value)} />
          </HudWidget>;
        })}
        {/* ── top right: the server, the ammo, the wallet, the identity ───────── */}
        {/* ★ Instead of the name, not beside it. A logo with the server's name spelled
            out next to it says the same thing twice, and the dot that marked "online"
            belongs to the text it sat against.

            Both come from the server: an admin sets them once for everybody, and a name
            left empty falls back to sv_projectName exactly as it always did. */}
        <HudWidget
          id="server"
          className="hw-right"
          override={{
            cfg: identityCfg,
            onPatch: identityPatch,
            tag: t('hud.identityTag'),
          }}
        >
          {srv.logo.url !== ''
            ? <HudMedia cfg={srv.logo} editing={editing} />
            : <div className="ti-server">
                <span>{srv.name !== '' ? srv.name : server}</span>
                <span className="dot" />
              </div>}
        </HudWidget>

        <HudWidget id="ammo" className="hw-right">
          <AmmoRow hands={ammoShown} />
        </HudWidget>

        <HudWidget id="money" className="hw-right">
          {/* Cash · bank · dirty · gold, on an ink plate (help_text_bg, the wheel's dialog
              plate) with the cash on top and a divider under it -- the figure that moves
              most sits apart from the three balances.
              The blue Rol row is gone on purpose: not one character on this server holds
              any, so it was a permanent zero taking a line from figures that move. Its
              icon stays bundled in vorpCurrencyIcons for whoever wants it back. */}
          <div className="plate wallet">
            <div className="plate-row is-cash">
              <span className="plate-val">{fmtMoney(cash)}</span>
              <span className="plate-ic"><CashIcon /></span>
            </div>
            <span className="plate-rule" aria-hidden="true" />
            <div className="plate-row">
              <span className="plate-val">{fmtMoney(bank)}</span>
              <span className="plate-ic"><BankIcon /></span>
            </div>
            <div className="plate-row is-dirty">
              <span className="plate-val">{fmtMoney(dirty)}</span>
              <span className="plate-ic"><DirtyIcon /></span>
            </div>
            <div className="plate-row is-gold">
              <span className="plate-val">{fmtMoney(gold)}</span>
              <span className="plate-ic"><GoldIcon /></span>
            </div>
          </div>
        </HudWidget>

        <HudWidget id="identity" className="hw-right">
          {/* The player: PvP (when the framework says), the server id, and the level with
              w_level's medallion -- one plate, the rows side by side. */}
          <div className="plate ident">
            {pvpShown !== null && (
              <div className={'plate-row is-pvp' + (pvpShown ? ' is-on' : '')}>
                <span className="plate-val is-word">{pvpShown ? t('hud.pvpOn') : t('hud.pvpOff')}</span>
                <span className="plate-ic"><PvpIcon /></span>
              </div>
            )}
            {idShown !== '' && (
              <div className="plate-row">
                <span className="plate-val">{idShown}</span>
                <span className="plate-ic"><IdIcon /></span>
              </div>
            )}
            {levelShown != null && (
              <div className="plate-row is-level">
                <span className="plate-val">{levelShown}</span>
                <span className="plate-ic is-medal"><LevelMedal /></span>
              </div>
            )}
          </div>
        </HudWidget>

        {/* ── bottom left: the effects and the state cores ────────────────────── */}
        {display.buffs?.show !== false && (
          <HudWidget id="buffs">
            <BuffRow buffs={hud.buffs} meta={buffMeta} />
          </HudWidget>
        )}

        {/* ★ The state is read from the same value the two stages are drawn from, or the
            colour would say one thing and the shape another. */}
        {vis('health', display.health, hud.health) && (
          <HudWidget id="health">
            <Core value={hud.health} icon={<HeartIcon />} brokenIcon={<BrokenHeartIcon />} title={t('hud.health')}
              color={tint('health', display.health?.color)} state={st('health', hud.health)}
              goldRing={hud.gilded?.healthRing} goldIcon={hud.gilded?.healthIcon}
              poisoned={!!hud.poisoned?.active} poisonRatio={hud.poisoned?.ratio ?? 1} />
          </HudWidget>
        )}

        {vis('stamina', display.stamina, hud.stamina) && (
          <HudWidget id="stamina">
            <Core value={hud.stamina} icon={<BoltIcon />} title={t('hud.stamina')}
              color={tint('stamina', display.stamina?.color)} state={st('stamina', hud.stamina)}
              goldRing={hud.gilded?.staminaRing} goldIcon={hud.gilded?.staminaIcon} />
          </HudWidget>
        )}

        {vis('hunger', display.hunger, hud.hunger) && (
          <HudWidget id="hunger">
            <Core value={hud.hunger} icon={<MeatIcon />} title={t('hud.food')}
              color={tint('hunger', display.hunger?.color)} state={st('hunger', hud.hunger)} />
          </HudWidget>
        )}

        {vis('thirst', display.thirst, hud.thirst) && (
          <HudWidget id="thirst">
            <Core value={hud.thirst} icon={<WaterIcon />} title={t('hud.water')}
              color={tint('thirst', display.thirst?.color)} state={st('thirst', hud.thirst)} />
          </HudWidget>
        )}

        {/* Voice is a core too: the ring = its level out of four */}
        <HudWidget id="voice">
          <div className={'voice-core' + (active ? ' on' : '')}>
            {/* ★ split=false: voice is a rank out of four, not a need that runs out. Halving it
                would make 'Whisper' a half-dimmed icon, and it is a rank, not a loss. */}
            <Core value={voiceFill} icon={<WaveIcon />} split={false} color={tint('voice')}
              title={hud.voiceLevel + '/' + hud.voiceLevels} />
          </div>
        </HudWidget>

        {/* Horse -- only while mounted */}
        {(hud.onHorse || showAll) && display.horse?.show !== false && (
          <HudWidget id="horseHealth">
            <Core value={hud.horsehealth} icon={<HorseIcon />} title={t('hud.horseHealth')}
              color={tint('horseHealth', display.horse?.color)} state={st('horseHealth', hud.horsehealth)} />
          </HudWidget>
        )}
        {(hud.onHorse || showAll) && display.horse?.show !== false && (
          <HudWidget id="horseStamina">
            <Core value={hud.horsestamina} icon={<HorseShoeIcon />} title={t('hud.horseStamina')}
              color={tint('horseStamina', display.horse?.color)} state={st('horseStamina', hud.horsestamina)} />
          </HudWidget>
        )}

        {/* ── top centre: the compass and the location ────────────────────────── */}
        <HudWidget id="compass">
          <Compass heading={heading} />
        </HudWidget>

        {/* Pictures the player added. An empty slot is nothing at all in the live HUD --
            it only takes up space in the editor, where it has to be placeable. */}
        {(['image1', 'image2', 'image3'] as const).map((id) => (
          (settings.media[id].url !== '' || editing) && (
            <HudWidget id={id} key={id}>
              <HudMedia cfg={settings.media[id]} editing={editing} />
            </HudWidget>
          )
        ))}

        {locationShown !== '' && (
          <HudWidget id="location">
            <div className="location">
              <span className="flourish">❖</span>{locationShown}<span className="flourish">❖</span>
            </div>
          </HudWidget>
        )}
      </HudLayoutProvider>
    </div>

    {editing && (
      <SettingsPanel
        settings={settings}
        selected={selected}
        saving={saving}
        select={setSelected}
        patch={patch}
        setTheme={setTheme}
        setGrid={setGrid}
        setScale={setScale}
        setShape={setShape}
        setWorld={setWorld}
        setMedia={setMedia}
        serverCfg={srv}
        isAdmin={isAdmin}
        srvState={srvState}
        editServer={editServer}
        publishServer={publishServer}
        setPanelPos={setPanelPos}
        resetWidget={resetWidget}
        resetPositions={resetPositions}
        resetAll={resetAll}
        saveProfile={saveProfile}
        applyProfile={applyProfile}
        clearProfile={clearProfile}
        importCode={importCode}
        onSave={flush}
        onClose={closeMenu}
      />
    )}
    </>
  );
}

export default App;
