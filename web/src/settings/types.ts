/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/types.ts
 * The model the whole panel is built on -- one widget, one record, no exceptions.
 *
 * ═══ Why every piece is its own widget ═══
 *
 *   The HUD used to be three clusters: a top-right column, a bottom-left row and a
 *   compass. Anything inside a cluster moved with it and could not be moved alone --
 *   so a player who wanted their food circle beside the minimap and their health in
 *   the centre had no way to say so.
 *
 *   Here every visible thing is a widget with its own position, scale, opacity,
 *   colour, visibility rule and warning thresholds. The old clusters survive only as
 *   **default coordinates** (`home` below), so an untouched HUD looks exactly as it
 *   did -- and the first drag is the only thing that changes it.
 * ════════════════════════════════════════════════════════════════════════════ */

import { normHex } from './color';
import { toTone } from './palette';

export type WidgetId =
  | 'server' | 'ammo' | 'money' | 'identity'
  | 'buffs'
  | 'health' | 'stamina' | 'hunger' | 'thirst' | 'voice'
  | 'horseHealth' | 'horseStamina'
  | 'companionHealth' | 'companionHunger' | 'companionThirst'
  | 'compass' | 'location'
  | 'image1' | 'image2' | 'image3';

export type WidgetGroup = 'status' | 'horse' | 'pet' | 'info' | 'nav' | 'media';

/* ════════════════════════════════════════════════════════════════════════════
 * Pictures
 *
 * ★ A link and nothing else. No upload, no file to add to the resource, no restart:
 *   the player pastes a URL and the thing appears. That is the whole feature, and it
 *   is what makes it usable by someone who cannot edit the server.
 *
 * ★ Every kind at once, because the browser already knows them all. A still PNG, an
 *   animated GIF, a WebP, an APNG, an SVG -- <img> plays each of them without being
 *   told which it is. Only the moving-picture formats need the other tag, so those are
 *   the only ones this file has to recognise (see isMotionFile).
 *
 * ⚠️ The scheme is checked and the length is capped, and both matter. `javascript:` in
 *   a src is a script the page runs, and an unbounded string here goes into the saved
 *   blob and then into the database. Anything that is not plain http, https or another
 *   resource's nui:// is dropped to an empty string -- which reads as 'no picture'
 *   rather than as an error, and no picture is the correct fallback.
 * ════════════════════════════════════════════════════════════════════════════ */

export interface MediaCfg {
  /** http(s):// or nui://. Empty means the widget shows nothing. */
  url: string;
  /** Width in rem -- the HUD's own unit (1rem = 0.64vh), so it scales with the screen. */
  width: number;
  /** Height in rem. 0 means follow the picture's own proportions. */
  height: number;
}

/**
 * The widgets a **player** may put a picture in.
 *
 * ⚠️ The server's logo is deliberately not here. It says whose server this is, so it
 *   belongs to whoever runs it -- it lives in ServerCfg below and arrives from the
 *   server for everyone at once. A player still owns where that block sits and how big
 *   it is; that is layout. What it says is not layout.
 */
export type MediaId = 'image1' | 'image2' | 'image3';
export const MEDIA_IDS: MediaId[] = ['image1', 'image2', 'image3'];

export const DEFAULT_MEDIA: MediaCfg = { url: '', width: 24, height: 0 };

/** 400 is generous for a link and small enough that four of them cannot bloat a save. */
const URL_MAX = 400;
const URL_OK = /^(https?:\/\/|nui:\/\/)/i;

export function safeUrl(v: unknown): string {
  if (typeof v !== 'string') return '';

  const url = v.trim();
  if (url === '' || !URL_OK.test(url)) return '';

  return url.slice(0, URL_MAX);
}

/**
 * Whether this link wants <video> rather than <img>.
 *
 * ⚠️ By extension, and it has to be: the tag is chosen before anything is fetched, so
 *   there is no content type to read yet. A link that hides its extension behind a query
 *   string still works -- the test ignores everything from ? or # onward -- and a video
 *   served from an extensionless URL falls back to <img>, fails, and says so in the
 *   editor rather than showing a blank rectangle.
 */
export function isMotionFile(url: string): boolean {
  return /\.(mp4|webm|ogv|ogg|mov|m4v)(\?|#|$)/i.test(url);
}

/**
 * When a widget is on screen.
 *   auto   -- follow the server's rule (Config.Display in shared/needs.lua)
 *   always -- never hidden
 *   below  -- only once the value falls to `showBelow`
 */
export type Visibility = 'auto' | 'always' | 'below';

export interface WidgetCfg {
  /** Position of the widget's origin point, in percent of the viewport. */
  x: number;
  y: number;
  /** 0.5 .. 2 -- multiplies the widget's own size only. */
  scale: number;
  /** 0.15 .. 1. Higher is more solid: this is opacity, whatever the label says. */
  opacity: number;
  show: boolean;
  /** Locked widgets are skipped by dragging -- so a finished layout is not nudged by accident. */
  locked: boolean;
  /** null = follow the theme accent. */
  color: string | null;
  visibility: Visibility;
  /** Only read when visibility is 'below'. */
  showBelow: number;
  /**
   * The two warning lines, per widget. null = follow the server's Config.Thresholds.
   *
   * ★ Per widget rather than one pair for everything, because the needs do not warn at
   *   the same point: hunger at 40 is a nuisance and health at 40 is an emergency, and
   *   one shared number has to be wrong for one of them.
   */
  warn: number | null;
  danger: number | null;
}

export interface Theme {
  /** Rings, numerals, the compass needle, the bars -- the HUD's leading colour. */
  accent: string;
  /** Body text and labels. */
  text: string;
  /** Secondary text, ticks, minor cardinals. */
  dim: string;
  /** The warning state (paper-dim by default). Any colour: painted exactly as chosen (palette.ts). */
  warn: string;
  /** The danger state -- the theme's red, the one mark the HUD may paint red. */
  danger: string;
  /** Poisoning -- the heart's ring while its fumes rise (paper-faint by default). */
  poison: string;
  /**
   * The wallet's figures and their icons (cash, bank, dirty, gold). Any colour, painted as chosen.
   * '' = none chosen: the stock look (the figures in the text tone, the icons a step dimmer, the
   * dirty money dim), so the wallet stays exactly as it was until a player picks a colour.
   */
  money: string;
}

/**
 * How the circles are drawn -- one set for all of them.
 *
 * ★ Global, not per widget, on purpose. Circles of different ring thicknesses side by
 *   side do not read as a set, they read as a mistake. What varies between them is
 *   colour and meaning; what makes them one family is shape.
 */
export interface ShapeCfg {
  /** Ring thickness on the 0-100 SVG canvas. 8 is the stock weight. */
  ring: number;
  /** How solid the dark disc behind the icon is. 0 leaves the icon floating. */
  disc: number;
  /** The icon's share of the disc. 0.64 is stock (~52% of the whole circle). */
  icon: number;
  /** Heartbeats, warning pulses, gilding shimmer, poison fumes. */
  motion: boolean;
}

/** off = no minimap · map = the map · compass = the game's compass strip */
export type MapMode = 'server' | 'off' | 'map' | 'compass';

/**
 * ⚠️ 'server' is the default and it means *do not interfere*. A server that turned the
 *   minimap off on foot did so for a reason, and a player setting that silently
 *   overrode it on first load would undo that decision for everyone who never opened
 *   this panel. The override happens only when the player asks for one.
 */
export interface WorldCfg {
  onFoot: MapMode;
  mounted: MapMode;
}

export interface GridCfg {
  snap: boolean;
  /** Grid step in percent of the viewport width. */
  size: number;
  /** Alignment guides against the other widgets while dragging. */
  guides: boolean;
}

/** A saved layout. Positions, colours and shape -- not the editor's own preferences. */
export interface Profile {
  name: string;
  theme: Theme;
  scale: number;
  shape: ShapeCfg;
  widgets: Record<WidgetId, WidgetCfg>;
  media: Record<MediaId, MediaCfg>;
}

export const PROFILE_SLOTS = 3;

export interface HudSettings {
  /** Bumped whenever the shape below changes in a way old saves cannot satisfy. */
  v: number;
  theme: Theme;
  /** A multiplier over every widget's own scale. */
  scale: number;
  shape: ShapeCfg;
  world: WorldCfg;
  grid: GridCfg;
  widgets: Record<WidgetId, WidgetCfg>;
  media: Record<MediaId, MediaCfg>;
  profiles: Array<Profile | null>;
  /**
   * Where the control panel itself was left, in percent of the viewport.
   *
   * ★ Saved with everything else on purpose. Someone laying out the bottom-left circles
   *   drags the panel off them first; if it came back over them on the next open they
   *   would move it again every single time.
   */
  panel: { x: number; y: number };
}

/* ════════════════════════════════════════════════════════════════════════════
 * The registry
 * ════════════════════════════════════════════════════════════════════════════ */

export interface WidgetMeta {
  id: WidgetId;
  group: WidgetGroup;
  /** A dictionary key (ui.widget.<id> in locales/{ar,en}.json), rendered with t(). */
  label: string;
  /** Which point of the widget's own box sits on (x, y). [1, 0] = its top-right corner. */
  origin: [number, number];
  home: { x: number; y: number };
  /**
   * The unit `home.x` was authored in.
   *
   * ⚠️ This is not a detail. The circles were anchored at `left: 27vh` -- measured
   *   against the **height**, because that is what the minimap is sized by, and the
   *   whole point of that number was to sit beside it. Baking it into a percentage of
   *   the width pins it to one aspect ratio: on 21:9 the row lands ~130px to the right
   *   of the minimap it is supposed to hug, and on 4:3 it lands on top of it. So the
   *   unit travels with the number and the conversion happens against the real viewport.
   */
  xUnit?: 'vw' | 'vh';
  /** Whether a colour of its own means anything for this widget. */
  tint: boolean;
  /** A gauge with a value -- so warning thresholds and a 'show below' rule apply. */
  gauge: boolean;
  /** Can carry a picture instead of (or as) its content. */
  media?: boolean;
  /** The Config.Display key it mirrors, where there is one. */
  displayKey?: string;
}

/* ── the bottom-left row of circles ───────────────────────────────────────────
   The original: .status-cluster { left: 27vh; bottom: 3vh } with .cores { gap: 1.1rem }
   and .core { 7.6rem }, at 1rem = 0.64vh:

     circle     = 7.6rem = 4.864vh          half = 2.432vh
     gap        = 1.1rem = 0.704vh
     step       = 5.568vh
     first x    = 27 + 2.432 = 29.432vh from the left edge
     y (centre) = 100 - 3 - 2.432 = 94.57
   ─────────────────────────────────────────────────────────────────────────── */
const CORE_Y = 94.6;
const CORE_X = (i: number) => Math.round((29.432 + i * 5.568) * 100) / 100;

/* ── the top-right column ─────────────────────────────────────────────────────
   .top-info { top: 2vh; right: 1.8vw } then .ti-stats { margin-top: 6.6vh; gap: 0.72rem }.

     .ti-server  2.6rem at line-height normal ~ 3.12rem = 2.00vh
     gap 0.2rem                                         = 0.13vh
     margin-top                                         = 6.60vh  -> ammo at 10.73
     .ammo-row   2.8rem + 0.2rem margin                 = 1.92vh
     gap 0.72rem                                        = 0.46vh  -> money at 13.11
     4 money rows (cash · bank · dirty · gold). The row's floor is 2.85rem; the
     currency PNGs are 3.15rem and win, the drawn bank icon is 2.45rem and loses
     to the floor:  3 x 3.15rem + 1 x 2.85rem + 3 x 0.72rem = 14.46rem = 9.25vh
     gap                                                           -> identity at 22.81

   ⚠️ Those money rows were first written down as 2.85rem -- the min-height rather than
      what actually renders -- which put the identity block 0.6vh high and ate the gap
      between the two. The floor is not the height whenever the content is taller.

   ⚠️ And the row count is part of the sum. The wallet was three rows when this was
      first worked out (tokens · gold · cash); the blue Rol row went and bank and
      dirty money came, so it is four. Left at the three-row figure, the identity
      block sat 2.3vh inside the wallet and the two columns printed over each other.
   ─────────────────────────────────────────────────────────────────────────── */
const RIGHT_X = 98.2;

export const WIDGETS: WidgetMeta[] = [
  /* -- the state circles, bottom left -- */
  { id: 'health', group: 'status', label: 'widget.health',
    origin: [0.5, 0.5], home: { x: CORE_X(0), y: CORE_Y }, xUnit: 'vh',
    tint: true, gauge: true, displayKey: 'health' },
  { id: 'stamina', group: 'status', label: 'widget.stamina',
    origin: [0.5, 0.5], home: { x: CORE_X(1), y: CORE_Y }, xUnit: 'vh',
    tint: true, gauge: true, displayKey: 'stamina' },
  { id: 'hunger', group: 'status', label: 'widget.hunger',
    origin: [0.5, 0.5], home: { x: CORE_X(2), y: CORE_Y }, xUnit: 'vh',
    tint: true, gauge: true, displayKey: 'hunger' },
  { id: 'thirst', group: 'status', label: 'widget.thirst',
    origin: [0.5, 0.5], home: { x: CORE_X(3), y: CORE_Y }, xUnit: 'vh',
    tint: true, gauge: true, displayKey: 'thirst' },
  { id: 'voice', group: 'status', label: 'widget.voice',
    origin: [0.5, 0.5], home: { x: CORE_X(4), y: CORE_Y }, xUnit: 'vh',
    tint: true, gauge: false },

  /* -- the horse, only while mounted -- */
  { id: 'horseHealth', group: 'horse', label: 'widget.horseHealth',
    origin: [0.5, 0.5], home: { x: CORE_X(5), y: CORE_Y }, xUnit: 'vh',
    tint: true, gauge: true, displayKey: 'horse' },
  { id: 'horseStamina', group: 'horse', label: 'widget.horseStamina',
    origin: [0.5, 0.5], home: { x: CORE_X(6), y: CORE_Y }, xUnit: 'vh',
    tint: true, gauge: true, displayKey: 'horse' },

  /* Smaller companion cores, above the player row with space for effect badges. */
  { id: 'companionHealth', group: 'pet', label: 'widget.companionHealth',
    origin: [0.5, 0.5], home: { x: CORE_X(0), y: CORE_Y - 7.2 }, xUnit: 'vh', tint: true, gauge: true },
  { id: 'companionHunger', group: 'pet', label: 'widget.companionHunger',
    origin: [0.5, 0.5], home: { x: CORE_X(0) + 4.5, y: CORE_Y - 7.2 }, xUnit: 'vh', tint: true, gauge: true },
  { id: 'companionThirst', group: 'pet', label: 'widget.companionThirst',
    origin: [0.5, 0.5], home: { x: CORE_X(0) + 9, y: CORE_Y - 7.2 }, xUnit: 'vh', tint: true, gauge: true },

  /* -- effects, just above the player circles -- */
  { id: 'buffs', group: 'status', label: 'widget.buffs',
    origin: [0, 1], home: { x: 27, y: 91.5 }, xUnit: 'vh',
    tint: false, gauge: false, displayKey: 'buffs' },

  /* -- the top-right column -- */
  { id: 'server', group: 'info', label: 'widget.server',
    origin: [1, 0], home: { x: RIGHT_X, y: 2.0 }, tint: true, gauge: false },
  { id: 'ammo', group: 'info', label: 'widget.ammo',
    origin: [1, 0], home: { x: RIGHT_X, y: 10.7 }, tint: true, gauge: false },
  { id: 'money', group: 'info', label: 'widget.money',
    origin: [1, 0], home: { x: RIGHT_X, y: 13.1 }, tint: true, gauge: false },
  /* ★ 25.0, not 22.8: the wallet is an ink plate now (padding + the rule under the cash),
     ~10.6vh tall from 13.1 -- measured on the rendered page, not summed from the rules. */
  { id: 'identity', group: 'info', label: 'widget.identity',
    origin: [1, 0], home: { x: RIGHT_X, y: 25.0 }, tint: true, gauge: false },

  /* -- navigation, top centre -- */
  { id: 'compass', group: 'nav', label: 'widget.compass',
    origin: [0.5, 0], home: { x: 50, y: 1.6 }, tint: true, gauge: false },
  { id: 'location', group: 'nav', label: 'widget.location',
    origin: [0.5, 0], home: { x: 50, y: 4.2 }, tint: true, gauge: false },

  /* -- pictures the player adds themselves --
     ★ Centred by default and empty by default, which is not a contradiction: a slot with
       no link draws nothing at all in the live HUD, so the middle of the screen costs
       nobody anything until they put something there -- and then it is where they will
       look for it. */
  { id: 'image1', group: 'media', label: 'widget.image1',
    origin: [0.5, 0.5], home: { x: 50, y: 30 }, tint: false, gauge: false, media: true },
  { id: 'image2', group: 'media', label: 'widget.image2',
    origin: [0.5, 0.5], home: { x: 50, y: 45 }, tint: false, gauge: false, media: true },
  { id: 'image3', group: 'media', label: 'widget.image3',
    origin: [0.5, 0.5], home: { x: 50, y: 60 }, tint: false, gauge: false, media: true },
];

export const WIDGET_BY_ID: Record<WidgetId, WidgetMeta> =
  WIDGETS.reduce((acc, meta) => { acc[meta.id] = meta; return acc; },
    {} as Record<WidgetId, WidgetMeta>);

/** Dictionary keys (ui.group.<group>), rendered with t(). */
export const GROUP_LABEL: Record<WidgetGroup, string> = {
  status: 'group.status',
  horse:  'group.horse',
  pet:    'group.pet',
  info:   'group.info',
  nav:    'group.nav',
  media:  'group.media',
};

/* ── viewport ────────────────────────────────────────────────────────────────
   height / width. Multiplying a vh figure by it converts it to a percentage of the
   width, which is the unit a position is stored and dragged in. */
export function aspect(): number {
  if (typeof window === 'undefined' || !window.innerWidth) return 9 / 16;
  return window.innerHeight / window.innerWidth;
}

/** A widget's default x for the screen it is actually being drawn on. */
export function homeX(meta: WidgetMeta, a = aspect()): number {
  const x = meta.xUnit === 'vh' ? meta.home.x * a : meta.home.x;
  return Math.round(x * 100) / 100;
}

/* ════════════════════════════════════════════════════════════════════════════
 * Defaults
 * ★ The stock palette verbatim -- Red Dead's white and black: the Wraith theme's paper on the
 *   game (w_lib/nui/theme: the loading screen and the pause menu), its one red for danger, and
 *   the two other states as paper a step and two steps down. A player who resets must land
 *   exactly on the HUD they were shipped, not on something near it; hud.css carries the same
 *   values for the first frame.
 * ════════════════════════════════════════════════════════════════════════════ */

export const DEFAULT_THEME: Theme = {
  accent: '#F2F2F2',   /* paper */
  text:   '#F2F2F2',   /* paper */
  dim:    '#B4B4B4',   /* paper-dim */
  warn:   '#B4B4B4',   /* paper-dim: the core dims as it runs down */
  danger: '#CB0101',   /* the theme's red: the mark */
  poison: '#7A7A7A',   /* paper-faint, with the fumes */
  money:  '',          /* none chosen: the wallet keeps its stock tones (hud.css) */
};

/* ★ The stock palettes of earlier builds: pure white on neutral grey, then the theme's warm
   (cream) paper with a yellow warning and a green poison, then that warm paper alone. A save that
   still holds exactly one of these never chose it: the whole default travels back with any layout
   the player saved. It is read as today's stock, so a player who never touched the colours
   follows the theme; any palette they did choose, even one field of it, is kept as it is (and
   drawn clamped, see palette.ts).

   ⚠️ Saved data, not paint: these are matched against what players have stored, so they stay
   exactly as those builds wrote them. They are written without their '#' so that a colour sweep
   over the sources (such as the warm -> neutral pass) cannot "fix" them and break the match.
   None of those builds had a money colour, so a save of theirs reads it as '' (none chosen). */
const oldStock = (accent: string, text: string, dim: string, warn: string, danger: string, poison: string): Theme => ({
  accent: '#' + accent, text: '#' + text, dim: '#' + dim, warn: '#' + warn, danger: '#' + danger, poison: '#' + poison,
  money: '',
});
const OLD_STOCKS: Theme[] = [
  oldStock('FFFFFF', 'F5F5F5', 'BFBFBF', 'E8C547', 'E52D2D', '5AB054'),
  oldStock('EDE6D6', 'EDE6D6', 'B9AF9C', 'E8C547', 'CB0101', '5AB054'),
  oldStock('EDE6D6', 'EDE6D6', 'B9AF9C', 'B9AF9C', 'CB0101', '7D7466'),
];

export const DEFAULT_SHAPE: ShapeCfg = { ring: 8, disc: 1, icon: 0.64, motion: true };
export const DEFAULT_WORLD: WorldCfg = { onFoot: 'server', mounted: 'server' };

/** v3 replaces the companion card with three independently editable cores.
    v4 paints the warning colour exactly as chosen (see FREE_WARN_SINCE). */
export const SETTINGS_VERSION = 4;

/**
 * The first version whose warning colour is painted as it is stored.
 *
 * ⚠️ Before it, every warning colour was drawn as the nearest ink/paper tone -- an old build's
 *   yellow default and a hue picked before the neutral pass alike were shown as paper-dim. A save
 *   (or a profile, or a share code) older than this is read as the tone it was drawn in, so
 *   opening this build changes nothing on anyone's screen; the free colour is for what is picked
 *   from now on. Its own number rather than SETTINGS_VERSION, which will move again for other
 *   reasons and must not drag a v4 save back into the clamp when it does.
 */
const FREE_WARN_SINCE = 4;
const isLegacy = (v: unknown): boolean => !(Number(v) >= FREE_WARN_SINCE);

export function defaultWidget(meta: WidgetMeta, a = aspect()): WidgetCfg {
  return {
    x: homeX(meta, a),
    y: meta.home.y,
    scale: 1,
    opacity: 1,
    show: true,
    locked: false,
    color: null,
    visibility: 'auto',
    showBelow: 50,
    warn: null,
    danger: null,
  };
}

export function defaultMedia(): Record<MediaId, MediaCfg> {
  const media = {} as Record<MediaId, MediaCfg>;
  for (const id of MEDIA_IDS) media[id] = { ...DEFAULT_MEDIA };
  return media;
}

export function defaultSettings(): HudSettings {
  const a = aspect();
  const widgets = {} as Record<WidgetId, WidgetCfg>;
  for (const meta of WIDGETS) widgets[meta.id] = defaultWidget(meta, a);

  return {
    v: SETTINGS_VERSION,
    theme: { ...DEFAULT_THEME },
    scale: 1,
    shape: { ...DEFAULT_SHAPE },
    world: { ...DEFAULT_WORLD },
    grid: { snap: true, size: 0.5, guides: true },
    widgets,
    media: defaultMedia(),
    profiles: new Array(PROFILE_SLOTS).fill(null),
    panel: { x: 60, y: 6 },
  };
}

/* ════════════════════════════════════════════════════════════════════════════
 * Presets -- whole palettes, not single colours
 *
 * ★ A palette is a set that agrees with itself. Offering the player six pickers and
 *   nothing else guarantees most of them end up with a HUD that fights itself, so the
 *   ready-made sets come first and the pickers are there for whoever wants them.
 *
 * ★ White and black only, like Red Dead: the sets differ in how bright the paper is, never
 *   in hue, and every one keeps the red for danger alone. The two free colours (a warning
 *   hue, a money colour) are the player's own business: a set leaves the money as none
 *   chosen and puts the warning back on a tone.
 * ════════════════════════════════════════════════════════════════════════════ */

/** `label` is a dictionary key (ui.preset.<id>). */
export interface ThemePreset { id: string; label: string; theme: Theme }

export const THEME_PRESETS: ThemePreset[] = [
  { id: 'stock', label: 'preset.stock', theme: { ...DEFAULT_THEME } },
  { id: 'bright', label: 'preset.bright',
    theme: { accent: '#FFFFFF', text: '#FFFFFF', dim: '#F2F2F2', warn: '#B4B4B4', danger: '#CB0101', poison: '#7A7A7A', money: '' } },
  { id: 'ash', label: 'preset.ash',
    theme: { accent: '#B4B4B4', text: '#F2F2F2', dim: '#7A7A7A', warn: '#7A7A7A', danger: '#CB0101', poison: '#7A7A7A', money: '' } },
];

/**
 * `label` and `hint` are dictionary keys (ui.theme.<key>, ui.theme.<key>Hint).
 * ★ This list is also the whitelist a save is read through (readTheme): a key not here is dropped.
 *   free -- any colour: the full chooser (hue, ready colours, #hex) beside the tones, and painted
 *           exactly as chosen. Every other field is the tone shelf, drawn as the nearest tone.
 */
export const THEME_FIELDS: Array<{ key: keyof Theme; label: string; hint: string; free?: boolean }> = [
  { key: 'accent', label: 'theme.accent', hint: 'theme.accentHint' },
  { key: 'text', label: 'theme.text', hint: 'theme.textHint' },
  { key: 'dim', label: 'theme.dim', hint: 'theme.dimHint' },
  { key: 'warn', label: 'theme.warn', hint: 'theme.warnHint', free: true },
  { key: 'danger', label: 'theme.danger', hint: 'theme.dangerHint' },
  { key: 'poison', label: 'theme.poison', hint: 'theme.poisonHint' },
  { key: 'money', label: 'theme.money', hint: 'theme.moneyHint', free: true },
];

/* ════════════════════════════════════════════════════════════════════════════
 * Reading a saved value
 *
 * ⚠️ Everything below distrusts its input on purpose: what arrives has been through a
 *    database, a JSON round trip, a share code someone pasted from a friend, and
 *    possibly a build older than this one. A single NaN in `x` puts a widget off-screen
 *    with no way back except a wipe -- so every number is clamped and every unknown key
 *    dropped, and a save we cannot read at all becomes the defaults rather than an
 *    exception during render.
 * ════════════════════════════════════════════════════════════════════════════ */

const num = (v: unknown, fallback: number, lo: number, hi: number): number => {
  const n = Number(v);
  if (!isFinite(n)) return fallback;
  return n < lo ? lo : n > hi ? hi : n;
};

const bool = (v: unknown, fallback: boolean): boolean => (typeof v === 'boolean' ? v : fallback);

const pick = <T extends string>(v: unknown, allowed: readonly T[], fallback: T): T =>
  (typeof v === 'string' && (allowed as readonly string[]).includes(v)) ? v as T : fallback;

const VISIBILITY = ['auto', 'always', 'below'] as const;
const MAP_MODES = ['server', 'off', 'map', 'compass'] as const;

/**
 * `legacy`: the save predates FREE_WARN_SINCE, so its warning colour is read as the tone it was
 * drawn in. `money` accepts '' (none chosen) and otherwise a colour; anything unreadable is ''.
 */
function readTheme(raw: unknown, base: Theme, legacy = false): Theme {
  if (!raw || typeof raw !== 'object') return base;
  const src = raw as Record<string, unknown>;

  for (const field of THEME_FIELDS) {
    const value = src[field.key];
    if (value != null) base[field.key] = normHex(value, base[field.key]);
  }
  if (OLD_STOCKS.some((old) => THEME_FIELDS.every((f) => String(base[f.key]).toUpperCase() === old[f.key]))) Object.assign(base, DEFAULT_THEME);
  if (legacy) base.warn = toTone(base.warn);
  return base;
}

function readShape(raw: unknown, base: ShapeCfg): ShapeCfg {
  if (!raw || typeof raw !== 'object') return base;
  const src = raw as Record<string, unknown>;

  base.ring = num(src.ring, base.ring, 3, 16);
  base.disc = num(src.disc, base.disc, 0, 1);
  base.icon = num(src.icon, base.icon, 0.4, 0.85);
  base.motion = bool(src.motion, base.motion);
  return base;
}

function readWidgets(raw: unknown, base: Record<WidgetId, WidgetCfg>): Record<WidgetId, WidgetCfg> {
  const saved = (raw && typeof raw === 'object') ? raw as Record<string, unknown> : {};

  for (const meta of WIDGETS) {
    let entry = saved[meta.id];
    const petIndex = ['companionHealth', 'companionHunger', 'companionThirst'].indexOf(meta.id);
    if (!entry && petIndex !== -1) {
      // Keep old visibility/size preferences, placing new cores above the player's
      // saved health position. Saved v3 positions always take precedence, profiles included.
      const legacy = saved.companion;
      entry = {
        ...(legacy && typeof legacy === 'object' ? legacy : {}),
        x: base.health.x + petIndex * 4.5 * aspect(),
        y: base.health.y - 7.2,
      };
    }
    if (!entry || typeof entry !== 'object') continue;

    const w = entry as Record<string, unknown>;
    const cfg = base[meta.id];

    /* ★ -20..120 rather than 0..100: an anchor may legitimately sit slightly off-screen
       (a right-anchored column has its origin at 98.2 and its body to the left of it),
       and a hard 0..100 would drag such widgets inward on every load. */
    cfg.x = num(w.x, cfg.x, -20, 120);
    cfg.y = num(w.y, cfg.y, -20, 120);
    cfg.scale = num(w.scale, 1, 0.5, 2);
    cfg.opacity = num(w.opacity, 1, 0.15, 1);
    cfg.show = bool(w.show, true);
    cfg.locked = bool(w.locked, false);
    cfg.color = w.color == null ? null : normHex(w.color, '#F2F2F2');
    cfg.visibility = pick(w.visibility, VISIBILITY, 'auto');
    cfg.showBelow = num(w.showBelow, 50, 1, 100);
    cfg.warn = w.warn == null ? null : num(w.warn, 40, 1, 100);
    cfg.danger = w.danger == null ? null : num(w.danger, 20, 1, 100);
  }

  return base;
}

function readMedia(raw: unknown, base: Record<MediaId, MediaCfg>): Record<MediaId, MediaCfg> {
  if (!raw || typeof raw !== 'object') return base;
  const src = raw as Record<string, unknown>;

  for (const id of MEDIA_IDS) {
    const entry = src[id];
    if (!entry || typeof entry !== 'object') continue;

    const m = entry as Record<string, unknown>;
    base[id].url = safeUrl(m.url);
    base[id].width = num(m.width, DEFAULT_MEDIA.width, 2, 160);
    base[id].height = num(m.height, DEFAULT_MEDIA.height, 0, 160);
  }

  return base;
}

function readProfile(raw: unknown, index: number, legacy = false): Profile | null {
  if (!raw || typeof raw !== 'object') return null;
  const src = raw as Record<string, unknown>;

  const a = aspect();
  const widgets = {} as Record<WidgetId, WidgetCfg>;
  for (const meta of WIDGETS) widgets[meta.id] = defaultWidget(meta, a);

  return {
    name: typeof src.name === 'string' && src.name.trim() !== ''
      ? src.name.trim().slice(0, 24)
      : `#${index + 1}`,
    theme: readTheme(src.theme, { ...DEFAULT_THEME }, legacy),
    scale: num(src.scale, 1, 0.6, 1.8),
    shape: readShape(src.shape, { ...DEFAULT_SHAPE }),
    widgets: readWidgets(src.widgets, widgets),
    media: readMedia(src.media, defaultMedia()),
  };
}

export function mergeSettings(raw: unknown): HudSettings {
  const base = defaultSettings();
  if (!raw || typeof raw !== 'object') return base;

  const src = raw as Record<string, unknown>;
  /* The version the save was written by; the profiles inside it were written by the same build. */
  const legacy = isLegacy(src.v);

  readTheme(src.theme, base.theme, legacy);
  readShape(src.shape, base.shape);
  readWidgets(src.widgets, base.widgets);
  readMedia(src.media, base.media);

  base.scale = num(src.scale, 1, 0.6, 1.8);

  if (src.world && typeof src.world === 'object') {
    const world = src.world as Record<string, unknown>;
    base.world.onFoot = pick(world.onFoot, MAP_MODES, 'server');
    base.world.mounted = pick(world.mounted, MAP_MODES, 'server');
  }

  if (src.grid && typeof src.grid === 'object') {
    const g = src.grid as Record<string, unknown>;
    base.grid.snap = bool(g.snap, base.grid.snap);
    base.grid.guides = bool(g.guides, base.grid.guides);
    base.grid.size = num(g.size, base.grid.size, 0.1, 5);
  }

  if (src.panel && typeof src.panel === 'object') {
    const panel = src.panel as Record<string, unknown>;
    base.panel.x = num(panel.x, base.panel.x, 0, 88);
    base.panel.y = num(panel.y, base.panel.y, 0, 82);
  }

  if (Array.isArray(src.profiles)) {
    for (let i = 0; i < PROFILE_SLOTS; i += 1) base.profiles[i] = readProfile(src.profiles[i], i, legacy);
  }

  return base;
}

export function cloneMedia(m: Record<MediaId, MediaCfg>): Record<MediaId, MediaCfg> {
  const out = {} as Record<MediaId, MediaCfg>;
  for (const id of MEDIA_IDS) out[id] = { ...m[id] };
  return out;
}

export function cloneProfile(p: Profile): Profile {
  const widgets = {} as Record<WidgetId, WidgetCfg>;
  for (const meta of WIDGETS) widgets[meta.id] = { ...p.widgets[meta.id] };

  return {
    name: p.name, theme: { ...p.theme }, scale: p.scale,
    shape: { ...p.shape }, widgets, media: cloneMedia(p.media),
  };
}

/** A deep copy -- the panel edits a draft and only the draft. */
export function cloneSettings(s: HudSettings): HudSettings {
  const widgets = {} as Record<WidgetId, WidgetCfg>;
  for (const meta of WIDGETS) widgets[meta.id] = { ...s.widgets[meta.id] };

  return {
    v: s.v,
    theme: { ...s.theme },
    scale: s.scale,
    shape: { ...s.shape },
    world: { ...s.world },
    grid: { ...s.grid },
    widgets,
    media: cloneMedia(s.media),
    profiles: s.profiles.map((p) => (p ? cloneProfile(p) : null)),
    panel: { ...s.panel },
  };
}

/** What a profile captures out of the live settings -- the look, not the workbench. */
export function profileFrom(s: HudSettings, name: string): Profile {
  const widgets = {} as Record<WidgetId, WidgetCfg>;
  for (const meta of WIDGETS) widgets[meta.id] = { ...s.widgets[meta.id] };

  return {
    name, theme: { ...s.theme }, scale: s.scale,
    shape: { ...s.shape }, widgets, media: cloneMedia(s.media),
  };
}


/* ════════════════════════════════════════════════════════════════════════════
 * The server's own settings -- one set for everyone, and only an admin may touch them
 *
 * ═══ Why these are not in the config file ═══
 *
 *   Every number below is one somebody wants to try, watch, and change again five
 *   minutes later: how fast hunger falls, how hard starving hurts, whether it can kill.
 *   In shared/config.lua each of those is an edit, a `refresh`, a `restart`, and a
 *   guess about whether it felt right -- which is why in practice nobody tunes them and
 *   they sit at whatever they shipped as. Here the admin moves a slider and watches.
 *
 *   ⚠️ And that is exactly why the server clamps them too. A client is never trusted,
 *      but even a trusted admin can send `interval: 0` by dragging a slider to its end
 *      on a build where the minimum was wrong -- and an interval of zero is a loop with
 *      no wait in it, on the server, for every player at once. server/settings.lua
 *      clamps every one of these again before it stores or applies anything.
 *
 * ═══ The identity belongs here, not to the player ═══
 *
 *   The name and the logo in the corner say whose server this is. A player may put that
 *   block where they like, at the size they like -- that is layout. What it *says* is
 *   not theirs to change, so it lives in this record and arrives from the server.
 * ════════════════════════════════════════════════════════════════════════════ */

export interface ServerNeedsCfg {
  /** Points of hunger lost each tick, on the 0-100 scale. */
  hungerRate: number;
  thirstRate: number;
  /** Seconds between ticks. */
  interval: number;
}

export interface ServerDamageCfg {
  enabled: boolean;
  /** Damage begins once hunger falls to this. */
  hungerAt: number;
  thirstAt: number;
  /**
   * Health lost per tick, on the **0-100 scale the player sees**.
   *
   * ⚠️ Not RDR3's raw 0-600. The old config number was applied raw, so the shipped `1`
   *   removed one six-hundredth of a life every fifteen seconds -- about a quarter of a
   *   percent a minute, which is why starving a character to death took over two hours
   *   and looked to everyone like nothing was happening at all. The client multiplies
   *   by 6 at the point of use; here it is the number the admin can reason about.
   */
  amount: number;
  /** Seconds between ticks. */
  interval: number;
  /** Off: starving leaves you on your last legs but never finishes the job. */
  canKill: boolean;
}

export type FeatureId =
  | 'health' | 'stamina' | 'hunger' | 'thirst' | 'voice' | 'horse' | 'buffs'
  | 'ammo' | 'money' | 'identity' | 'compass' | 'location'
  | 'playerImages' | 'playerPanel';

/**
 * Where the name-or-logo block sits, in the same units as any other widget.
 *
 * ★ Placement travels with the branding rather than staying in each player's layout.
 *   A logo is a statement about whose server this is, and half of that statement is
 *   where it sits -- one player tucking it behind their minimap is not a layout
 *   preference, it is the branding being undone one screen at a time. The admin drags
 *   it once and everyone has it there.
 */
export interface IdentityCfg {
  x: number;
  y: number;
  scale: number;
  opacity: number;
}

export interface ServerCfg {
  /** Empty = fall back to the sv_projectName convar, as before. */
  name: string;
  /** A link. When set it replaces the name entirely, for everyone. */
  logo: MediaCfg;
  identity: IdentityCfg;
  needs: ServerNeedsCfg;
  damage: ServerDamageCfg;
  features: Record<FeatureId, boolean>;
}

/** Which widgets a switched-off feature takes with it. */
export const FEATURE_WIDGETS: Partial<Record<FeatureId, WidgetId[]>> = {
  health: ['health'],
  stamina: ['stamina'],
  hunger: ['hunger'],
  thirst: ['thirst'],
  voice: ['voice'],
  horse: ['horseHealth', 'horseStamina'],
  buffs: ['buffs'],
  ammo: ['ammo'],
  money: ['money'],
  identity: ['identity'],
  compass: ['compass'],
  location: ['location'],
  playerImages: ['image1', 'image2', 'image3'],
};

/** `label` is a dictionary key (ui.feature.<id>). */
export const FEATURES: Array<{ id: FeatureId; label: string }> = [
  { id: 'health', label: 'feature.health' },
  { id: 'stamina', label: 'feature.stamina' },
  { id: 'hunger', label: 'feature.hunger' },
  { id: 'thirst', label: 'feature.thirst' },
  { id: 'voice', label: 'feature.voice' },
  { id: 'horse', label: 'feature.horse' },
  { id: 'buffs', label: 'feature.buffs' },
  { id: 'ammo', label: 'feature.ammo' },
  { id: 'money', label: 'feature.money' },
  { id: 'identity', label: 'feature.identity' },
  { id: 'compass', label: 'feature.compass' },
  { id: 'location', label: 'feature.location' },
  { id: 'playerImages', label: 'feature.playerImages' },
  { id: 'playerPanel', label: 'feature.playerPanel' },
];

/* ★ The defaults are deliberately not the old config values.
     Those were 1 point of hunger every 144 seconds -- four hours from full to empty --
     and then a quarter of a percent of health a minute once below 5. A player could
     starve through an entire session and never see either happen, which is the thing
     that was reported. These are paced to be felt: about two and a half hours to empty,
     and roughly a quarter of an hour of ignoring it after that. */
export const DEFAULT_SERVER: ServerCfg = {
  name: '',
  logo: { url: '', width: 30, height: 0 },
  /* The same corner the block has always been in -- see the `server` entry in WIDGETS. */
  identity: { x: 98.2, y: 2.0, scale: 1, opacity: 1 },
  needs: { hungerRate: 1, thirstRate: 1.4, interval: 90 },
  damage: { enabled: true, hungerAt: 15, thirstAt: 15, amount: 2, interval: 20, canKill: true },
  features: {
    health: true, stamina: true, hunger: true, thirst: true, voice: true, horse: true,
    buffs: true, ammo: true, money: true, identity: true, compass: true, location: true,
    playerImages: true, playerPanel: true,
  },
};

export function defaultServer(): ServerCfg {
  return {
    name: '',
    logo: { ...DEFAULT_SERVER.logo },
    identity: { ...DEFAULT_SERVER.identity },
    needs: { ...DEFAULT_SERVER.needs },
    damage: { ...DEFAULT_SERVER.damage },
    features: { ...DEFAULT_SERVER.features },
  };
}

export function mergeServerCfg(raw: unknown): ServerCfg {
  const base = defaultServer();
  if (!raw || typeof raw !== 'object') return base;

  const src = raw as Record<string, unknown>;

  if (typeof src.name === 'string') base.name = src.name.trim().slice(0, 48);

  if (src.logo && typeof src.logo === 'object') {
    const logo = src.logo as Record<string, unknown>;
    base.logo.url = safeUrl(logo.url);
    base.logo.width = num(logo.width, base.logo.width, 2, 160);
    base.logo.height = num(logo.height, base.logo.height, 0, 160);
  }

  if (src.identity && typeof src.identity === 'object') {
    const id = src.identity as Record<string, unknown>;
    base.identity.x = num(id.x, base.identity.x, -20, 120);
    base.identity.y = num(id.y, base.identity.y, -20, 120);
    base.identity.scale = num(id.scale, base.identity.scale, 0.4, 3);
    base.identity.opacity = num(id.opacity, base.identity.opacity, 0.15, 1);
  }

  if (src.needs && typeof src.needs === 'object') {
    const n = src.needs as Record<string, unknown>;
    base.needs.hungerRate = num(n.hungerRate, base.needs.hungerRate, 0, 25);
    base.needs.thirstRate = num(n.thirstRate, base.needs.thirstRate, 0, 25);
    /* ⚠️ A floor of 5 seconds, not 0. Zero is a loop with no wait in it. */
    base.needs.interval = num(n.interval, base.needs.interval, 5, 1800);
  }

  if (src.damage && typeof src.damage === 'object') {
    const dmg = src.damage as Record<string, unknown>;
    base.damage.enabled = bool(dmg.enabled, base.damage.enabled);
    base.damage.hungerAt = num(dmg.hungerAt, base.damage.hungerAt, 0, 99);
    base.damage.thirstAt = num(dmg.thirstAt, base.damage.thirstAt, 0, 99);
    base.damage.amount = num(dmg.amount, base.damage.amount, 0.5, 25);
    base.damage.interval = num(dmg.interval, base.damage.interval, 3, 600);
    base.damage.canKill = bool(dmg.canKill, base.damage.canKill);
  }

  if (src.features && typeof src.features === 'object') {
    const f = src.features as Record<string, unknown>;
    for (const feature of FEATURES) base.features[feature.id] = bool(f[feature.id], true);
  }

  return base;
}

/** How long a need takes to run out at the current rate -- the number the sliders hide. */
export function drainMinutes(rate: number, intervalSeconds: number): number {
  if (rate <= 0) return Infinity;
  return (100 / rate) * (intervalSeconds / 60);
}

/** How long from the damage threshold to death, in minutes. Infinity when it cannot kill. */
export function deathMinutes(d: ServerDamageCfg): number {
  if (!d.enabled || !d.canKill || d.amount <= 0) return Infinity;
  return (100 / d.amount) * (d.interval / 60);
}

/* ════════════════════════════════════════════════════════════════════════════
 * The share code
 *
 * ★ A layout is worth an evening's fiddling, and the person who did the fiddling wants
 *   to hand it to their posse. A code they can paste in chat is the whole feature: no
 *   server, no upload, nothing to moderate.
 *
 * ⚠️ btoa cannot take Arabic -- it throws on anything above U+00FF, and layout names
 *   here are Arabic more often than not. encodeURIComponent first turns the whole
 *   string into ASCII percent-escapes, and decodeURIComponent puts it back. Without
 *   that pair, sharing a layout named 'قتال' throws where the player cannot see it.
 * ════════════════════════════════════════════════════════════════════════════ */

const CODE_PREFIX = 'WHUD1:';

export function encodeShare(p: Profile): string {
  try {
    /* v: which build wrote it -- a code from before FREE_WARN_SINCE has its warning read as a tone. */
    const json = JSON.stringify({ v: SETTINGS_VERSION, n: p.name, t: p.theme, s: p.scale, h: p.shape, w: p.widgets, m: p.media });
    return CODE_PREFIX + btoa(encodeURIComponent(json));
  } catch {
    return '';
  }
}

export function decodeShare(code: string): Profile | null {
  try {
    const body = code.trim().replace(/\s+/g, '');
    if (!body.startsWith(CODE_PREFIX)) return null;

    const json = decodeURIComponent(atob(body.slice(CODE_PREFIX.length)));
    const raw = JSON.parse(json) as Record<string, unknown>;

    /* Straight back through the same validator every other source goes through: a code
       from a stranger is the least trustworthy input this file has. */
    return readProfile(
      { name: raw.n, theme: raw.t, scale: raw.s, shape: raw.h, widgets: raw.w, media: raw.m },
      0,
      isLegacy(raw.v),
    );
  } catch {
    return null;
  }
}
