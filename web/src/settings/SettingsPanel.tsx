/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/SettingsPanel.tsx
 * The control panel -- in the HUD's own idiom, not a web form dropped on top of it.
 *
 * ═══ Why it is laid out this way ═══
 *
 *   The first version put everything on screen at once: a row of tabs, fourteen list
 *   rows each carrying two icon buttons, four section headings, a pinned inspector and
 *   a footer -- in one column the width of a phone. Every part of it was defensible and
 *   the whole was unreadable.
 *
 *   ★ 2.2.0: the panel is a board of the kit (../kit.css), like every other board on the
 *     server: a masthead (the handle), a head card naming the open section, the page card
 *     with the sections as text tabs on one line, and the actions strip. The rail of icon
 *     tabs, the framed window and the two footer plates are gone; what each section holds
 *     and does is unchanged.
 *
 *   ★ The element list is a grid of picks, not rows. Fourteen rows with two buttons each
 *     is twenty-eight controls competing for attention before you have chosen anything.
 *     Fourteen picks is one control: pick a thing. Its controls appear once it is picked.
 *
 *   ★ The cursor and the choice: the paper band under the pointer, the red mark band on what
 *     is chosen (the open section, the picked element, a switch that is on, the chosen slot,
 *     the main action). Hover only highlights; a click chooses.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type PointerEvent as ReactPointerEvent, type ReactNode } from 'react';
import { play } from '../wheel/nui';
import { useI18n, type TFn } from '../i18n';
import { ColorField } from './ColorField';
import { wsFontScale, wsGutter } from '../wsScale';
import {
  DEFAULT_THEME, FEATURES, FEATURE_WIDGETS, GROUP_LABEL, PROFILE_SLOTS, THEME_FIELDS, THEME_PRESETS,
  WIDGETS, WIDGET_BY_ID, deathMinutes, drainMinutes, encodeShare, moneyRowColour, profileFrom, safeUrl,
  type FeatureId, type GridCfg, type HudSettings, type MapMode, type MediaCfg,
  type MediaId, type ServerCfg, type ServerDamageCfg, type ServerNeedsCfg, type ShapeCfg,
  type Theme, type ThemeGroup, type ThemeKey, type Visibility, type WidgetCfg, type WidgetGroup,
  type WidgetId, type WorldCfg,
} from './types';

type Pane = 'elements' | 'colours' | 'shape' | 'display' | 'layout' | 'profiles' | 'admin';

export interface PanelProps {
  settings: HudSettings;
  selected: WidgetId | null;
  saving: 'idle' | 'dirty' | 'saving' | 'saved';
  select: (id: WidgetId | null) => void;
  patch: (id: WidgetId, p: Partial<WidgetCfg>) => void;
  setTheme: (t: Partial<Theme>) => void;
  setShape: (s: Partial<ShapeCfg>) => void;
  setWorld: (w: Partial<WorldCfg>) => void;
  setMedia: (id: MediaId, m: Partial<MediaCfg>) => void;
  setGrid: (g: Partial<GridCfg>) => void;
  setScale: (n: number) => void;
  setPanelPos: (x: number, y: number) => void;
  resetWidget: (id: WidgetId) => void;
  resetPositions: () => void;
  resetAll: () => void;
  saveProfile: (slot: number, name: string) => void;
  applyProfile: (slot: number) => void;
  clearProfile: (slot: number) => void;
  importCode: (code: string) => boolean;
  /** The state colour being looked at (a field hovered, its chooser open) -- the HUD shows it. */
  previewState: (key: ThemeKey | null) => void;
  /** The server's half -- everyone sees it, only an admin may change it. */
  serverCfg: ServerCfg;
  isAdmin: boolean;
  srvState: 'idle' | 'dirty' | 'saving' | 'saved';
  /** Applies at once on this screen; reaches everyone a moment after the last change. */
  editServer: (fn: (c: ServerCfg) => ServerCfg) => void;
  publishServer: () => void;
  onSave: () => void;
  onClose: () => void;
}

/* ════════════════════════════════════════════════════════════════════════════
 * The words
 *
 * ★ None of them live here. Every label is a key of the `ui.settings` section of
 *   locales/{ar,en}.json, handed over by Lua (see ../i18n.ts), so the panel follows the
 *   language the library decides and switches live with it.
 *
 *   Two of the old labels were wrong and both mattered, so the keys say what the control
 *   does: 'clarity' rises with the number (a slider whose maximum is fully opaque), and
 *   the block holding the PVP state, the player number and the level is 'player info'.
 * ════════════════════════════════════════════════════════════════════════════ */
const S = (key: string) => `settings.${key}`;

/** The panel's spot when the player never dragged it (types.ts defaults): the board docks
    at the inline-start edge like every board, inside the 16:9 frame (board.css .is-docked). */
const HOME = { x: 60, y: 6 };

/* ── glyphs (the kit's: thin strokes in the current colour) ────────────────── */
const GlyphBack = () => (
  <svg className="wf-glyph" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M10 3 5 8l5 5" /></svg>
);
const GlyphFwd = () => (
  <svg className="wf-glyph" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m6 3 5 5-5 5" /></svg>
);
const ResetIcon = () => (
  <svg className="wf-glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round">
    <path d="M4 12a8 8 0 1 0 2.6-5.9" /><path d="M4 4v4.4h4.4" />
  </svg>
);
const CloseIcon = () => (
  <svg className="wf-glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <path d="M6 6l12 12M18 6 6 18" />
  </svg>
);

const cls = (...p: Array<string | false | null | undefined>) => p.filter(Boolean).join(' ');

/* ── building blocks ────────────────────────────────────────────────────────── */

/**
 * A value along a line: the kit's stepper (arrows step it) with a thin track between the arrows,
 * paper up to the value -- the gauge rule. The range input under it keeps dragging and clicking.
 */
function Slider({ label, value, min, max, step, format, onChange }: {
  label: string; value: number; min: number; max: number; step: number;
  format?: (v: number) => string; onChange: (v: number) => void;
}) {
  const pct = max > min ? Math.max(0, Math.min(100, ((value - min) / (max - min)) * 100)) : 0;
  const nudge = (dir: number) => {
    const next = Math.max(min, Math.min(max, Math.round((value + dir * step) / step) * step));
    const tidy = Number(next.toFixed(4));
    if (tidy !== value) { play('select'); onChange(tidy); }
  };
  return (
    <div className="hs-slide">
      <span className="hs-slide-top">
        <span className="wf-label">{label}</span>
        <span className="hs-slide-val">{format ? format(value) : value.toFixed(2)}</span>
      </span>
      <div className="wf-stepper">
        <button type="button" className="wf-stepper-arrow" aria-label="-" onClick={() => nudge(-1)}><GlyphBack /></button>
        <input type="range" className="hs-range" min={min} max={max} step={step} value={value}
          style={{ '--v': `${pct}%` } as CSSProperties}
          onChange={(e) => onChange(Number(e.target.value))} />
        <button type="button" className="wf-stepper-arrow" aria-label="+" onClick={() => nudge(1)}><GlyphFwd /></button>
      </div>
    </div>
  );
}

/** The kit's on/off row: the word on the switch, the red mark band when it is on. */
function Toggle({ label, on, onChange }: { label: string; on: boolean; onChange: (v: boolean) => void }) {
  const { t } = useI18n();
  return (
    <button type="button" className="wf-switch-row"
      onClick={() => { play('select'); onChange(!on); }}>
      <span>{label}</span>
      <span className="wf-switch" data-on={on ? 'true' : 'false'}>{on ? t(S('on')) : t(S('off'))}</span>
    </button>
  );
}

/** One switch, or a column of them, in the kit's switch list. */
function Switches({ children, two }: { children: ReactNode; two?: boolean }) {
  return <div className={cls('wf-switches', 'hs-switches', !two && 'is-one')}>{children}</div>;
}

/** A choice among a few: the kit's stepper (◀ value ▶), the arrows walk the options. */
function Segmented<T extends string>({ label, value, options, onChange }: {
  label?: string; value: T;
  options: Array<{ value: T; label: string }>;
  onChange: (v: T) => void;
}) {
  const at = Math.max(0, options.findIndex((o) => o.value === value));
  const step = (dir: number) => {
    play('select');
    onChange(options[(at + dir + options.length) % options.length].value);
  };
  return (
    <div className="wf-field hs-choice">
      {label && <span className="wf-label">{label}</span>}
      <div className="wf-stepper">
        <button type="button" className="wf-stepper-arrow" aria-label="-" onClick={() => step(-1)}><GlyphBack /></button>
        <span className="wf-stepper-value">{options[at]?.label}</span>
        <button type="button" className="wf-stepper-arrow" aria-label="+" onClick={() => step(1)}><GlyphFwd /></button>
      </div>
    </div>
  );
}

/**
 * The link, and the two sizes that go with it.
 *
 * ⚠️ The field keeps its own draft and only commits when the player leaves it or presses
 *   Enter. Committing on every keystroke would mean running the URL check against
 *   "h", then "ht", then "htt" -- each of which fails -- so the value would be wiped as
 *   fast as it was typed. What is typed is the player's; what is stored has to be safe;
 *   the boundary between the two is this component.
 */
function MediaFields({ id, cfg, t, onChange }: {
  id: MediaId;
  cfg: MediaCfg;
  t: TFn;
  onChange: (id: MediaId, m: Partial<MediaCfg>) => void;
}) {
  const [draft, setDraft] = useState(cfg.url);
  const [bad, setBad] = useState(false);

  useEffect(() => { setDraft(cfg.url); setBad(false); }, [cfg.url]);

  const commit = () => {
    const value = draft.trim();

    if (value === '') { setBad(false); onChange(id, { url: '' }); return; }

    const ok = safeUrl(value) !== '';
    setBad(!ok);
    if (ok) onChange(id, { url: value });
  };

  return (
    <>
      <label className="wf-field hs-field-block">
        <span className="wf-label">{t(S('imageUrl'))}</span>
        <input
          className={cls('wf-input', 'hs-code', bad && 'is-invalid')}
          value={draft}
          spellCheck={false}
          placeholder="https://..."
          onChange={(e) => { setDraft(e.target.value); setBad(false); }}
          onBlur={commit}
          onKeyDown={(e) => { if (e.key === 'Enter') commit(); }}
        />
      </label>
      {bad ? <p className="wf-error">{t(S('imageBad'))}</p> : <p className="wf-note-line">{t(S('imageHint'))}</p>}

      {cfg.url !== '' && (
        <>
          <Slider label={t(S('imageW'))} value={cfg.width} min={2} max={160} step={1}
            format={(v) => String(Math.round(v))}
            onChange={(v) => onChange(id, { width: v })} />
          <Slider label={t(S('imageH'))} value={cfg.height} min={0} max={160} step={1}
            format={(v) => (v <= 0 ? t(S('imageAuto')) : String(Math.round(v)))}
            onChange={(v) => onChange(id, { height: v })} />
          <div className="wf-btns">
            <button type="button" className="wf-btn is-danger"
              onClick={() => { play('select'); onChange(id, { url: '' }); }}>
              {t(S('imageClear'))}
            </button>
          </div>
        </>
      )}
    </>
  );
}

/**
 * One colour of the theme: its name, what it paints, and the chooser.
 *
 * ★ Every field has a way back: a field that may be none chosen (the money, each wallet row) offers
 *   what it follows; every other field offers its stock colour ("Default").
 * ★ Hovering the field or opening its chooser previews it on the HUD (App.tsx previewLook), so a
 *   poison or a booster colour is picked while looking at a poisoned or boosted circle.
 */
function ThemeColour({ field, settings, t, setTheme, preview }: {
  field: (typeof THEME_FIELDS)[number];
  settings: HudSettings;
  t: TFn;
  setTheme: (patch: Partial<Theme>) => void;
  preview: (key: ThemeKey | null) => void;
}) {
  const theme = settings.theme;
  const key = field.key;
  const value = theme[key];
  const open = useRef(false);

  /* What the swatch shows while the field is none chosen: what is drawn in its place. */
  const shown = field.empty === 'stock' ? (value || theme.text)
    : field.empty === 'wallet' ? moneyRowColour(theme, settings.widgets.money.color, key)
      : value;

  const set = (hex: string) => setTheme({ [key]: hex } as Partial<Theme>);

  return (
    <li className="hs-field"
      onMouseEnter={() => preview(key)}
      onMouseLeave={() => { if (!open.current) preview(null); }}>
      <span className="hs-field-text">
        <b>{t(field.label)}</b>
        <em>{t(field.hint)}</em>
      </span>
      <ColorField
        value={shown}
        onChange={set}
        red={key === 'danger'}
        onOpenChange={(o) => { open.current = o; preview(o ? key : null); }}
        inherit={field.empty ? {
          active: value === '',
          label: t(S(field.empty === 'stock' ? 'moneyStock' : 'inheritWallet')),
          onPick: () => set(''),
        } : undefined}
        reset={field.empty ? undefined : {
          active: value === DEFAULT_THEME[key],
          label: t(S('fieldDefault')),
          onPick: () => set(DEFAULT_THEME[key]),
        }}
      />
    </li>
  );
}

function Section({ title, note, children }: { title?: string; note?: string; children: ReactNode }) {
  return (
    <section className="hs-block">
      {title && <h3 className="wf-sec">{title}</h3>}
      {children}
      {note && <p className="wf-note-line">{note}</p>}
    </section>
  );
}

/* ════════════════════════════════════════════════════════════════════════════
 * The panel
 * ════════════════════════════════════════════════════════════════════════════ */

const PLAYER_PANES: Pane[] = ['elements', 'colours', 'shape', 'display', 'layout', 'profiles'];

/** minutes -> "2 hours 30 min", in Latin digits whatever the language. */
function duration(mins: number, t: TFn, never: string): string {
  if (!isFinite(mins)) return never;
  if (mins < 1) return `< 1 ${t(S('minute'))}`;

  const h = Math.floor(mins / 60);
  const m = Math.round(mins % 60);

  if (h <= 0) return `${m} ${t(S('minute'))}`;
  if (m === 0) return `${h} ${t(S('hour'))}`;
  return `${h} ${t(S('hour'))} ${m} ${t(S('minute'))}`;
}

/* ════════════════════════════════════════════════════════════════════════════
 * The admin pane in words (2026-11-12, the notebook design)
 *
 * ★ The server's numbers are rates -- "1.4 every 90 seconds" -- and nobody reads a rate as
 *   a time. So the pane leads with what every player has NOW, in sentences, and the main
 *   controls are times ("hunger runs out in 4 hours"). Each choice is turned back into the
 *   same rate the server stores, so the saved shape and server/admin.lua's clamps are
 *   untouched; the exact sliders sit under «خيارات متقدمة» for whoever wants a number.
 * ════════════════════════════════════════════════════════════════════════════ */

/** "{name}" placeholders, filled with a replacer (a `$` in a name must stay a `$`). */
const fill = (s: string, vars: Record<string, string>) =>
  s.replace(/\{(\w+)\}/g, (m: string, k: string) => (k in vars ? vars[k] : m));

/** A spot in percent of the screen -> the dictionary key of its words (posTR = top right). */
function posKey(x: number, y: number): string {
  const v = y < 34 ? 'T' : y > 66 ? 'B' : 'M';
  const h = x < 34 ? 'L' : x > 66 ? 'R' : 'C';
  return `pos${v}${h}`;
}

const DRAIN_STEPS = [30, 60, 90, 120, 150, 180, 240, 360, 480, 720];
const DEATH_STEPS = [10, 15, 30, 60, 120, 240];
const AT_STEPS = [5, 10, 15, 20, 25, 30, 50];
const round3 = (n: number) => Number(n.toFixed(3));
const near = (a: number, b: number) => Math.abs(a - b) <= Math.max(1, b * 0.02);

type Opt = { value: string; label: string };

/**
 * The time choices for a value stored as a rate. `feasible` drops the times the server's
 * clamps could not hold; a value that matches no step shows as «مخصَّص: …» and stays
 * chosen until another step is picked.
 */
function timeChoices(current: number, steps: number[], feasible: (mins: number) => boolean,
  t: TFn, never?: string): { value: string; options: Opt[] } {
  const options: Opt[] = steps.filter(feasible).map((m) => ({ value: String(m), label: duration(m, t, '') }));
  if (never) options.push({ value: 'never', label: never });

  if (!isFinite(current)) {
    if (never) return { value: 'never', options };
  } else {
    const hit = options.find((o) => o.value !== 'never' && near(current, Number(o.value)));
    if (hit) return { value: hit.value, options };
  }
  const label = fill(t(S('srvCustom')), { v: duration(current, t, never ?? t(S('srvNever'))) });
  return { value: 'custom', options: [{ value: 'custom', label }, ...options] };
}

/** «خيارات متقدمة»: closed by default; the values inside are kept either way. */
function Fold({ open, onToggle, label, note, children }: {
  open: boolean; onToggle: () => void; label: string; note: string; children: ReactNode;
}) {
  return (
    <div className={cls('hs-fold', open && 'is-open')}>
      <button type="button" className="hs-fold-btn" aria-expanded={open}
        onClick={() => { play('select'); onToggle(); }}>
        <span>{label}</span>
        <svg className="wf-glyph hs-fold-chev" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m4 6 4 4 4-4" /></svg>
      </button>
      {open && (
        <div className="hs-fold-body">
          <p className="wf-note-line">{note}</p>
          {children}
        </div>
      )}
    </div>
  );
}
const GROUP_ORDER: WidgetGroup[] = ['status', 'horse', 'pet', 'info', 'nav', 'media'];
const COLOUR_GROUPS: ThemeGroup[] = ['base', 'states', 'wallet'];
/** The circles: an element of these with no colour of its own follows the circles' colour. */
const CORE_GROUPS: WidgetGroup[] = ['status', 'horse', 'pet'];

/** What the paper note asks before a step that cannot be undone. */
type Ask = { kind: 'resetAll' } | { kind: 'clearSlot'; slot: number };

export function SettingsPanel(p: PanelProps) {
  const { t, dir } = useI18n();
  const rtl = dir === 'rtl';
  const [pane, setPane] = useState<Pane>('elements');
  const [code, setCode] = useState('');
  const [codeNote, setCodeNote] = useState<'' | 'ok' | 'bad' | 'copied'>('');
  /** Which card the pointer is in -- it carries the red tick ribbon. */
  const [focus, setFocus] = useState<'head' | 'page' | 'actions'>('page');
  /** The chosen saved-layout slot; the slot actions act on it only. */
  const [slotSel, setSlotSel] = useState<number | null>(null);
  const [ask, setAsk] = useState<Ask | null>(null);

  /* The logo link keeps a draft while it is being typed, for the reason MediaFields does:
     checking a half-typed URL fails, and a failed check would wipe it mid-word. */
  const [logoDraft, setLogoDraft] = useState(p.serverCfg.logo.url);
  const [logoBad, setLogoBad] = useState(false);
  /** The admin pane's three «خيارات متقدمة» folds. */
  const [adv, setAdv] = useState({ id: false, needs: false, dmg: false });
  const logoRef = useRef<HTMLInputElement>(null);
  const idRef = useRef<HTMLDivElement>(null);
  const needsRef = useRef<HTMLDivElement>(null);
  const dmgRef = useRef<HTMLDivElement>(null);
  const featRef = useRef<HTMLDivElement>(null);

  /* ★ Live, not a draft. Every one of these applies on this screen the moment it is
     touched -- an admin sizing a logo has to watch it -- and App.tsx sends the result to
     everyone else a moment after the adjusting stops. The button below is there to
     publish immediately and to say what state the settings are in. */
  const srvDraft = p.serverCfg;

  const editNeeds = (n: Partial<ServerNeedsCfg>) =>
    p.editServer((c) => ({ ...c, needs: { ...c.needs, ...n } }));
  const editDamage = (dmg: Partial<ServerDamageCfg>) =>
    p.editServer((c) => ({ ...c, damage: { ...c.damage, ...dmg } }));
  const editFeature = (id: FeatureId, on: boolean) =>
    p.editServer((c) => ({ ...c, features: { ...c.features, [id]: on } }));
  const editIdentity = (next: Partial<ServerCfg>) =>
    p.editServer((c) => ({ ...c, ...next }));
  const pos = p.settings.panel;
  const docked = pos.x === HOME.x && pos.y === HOME.y;
  const shareRef = useRef<HTMLInputElement>(null);
  /** The picked element's controls sit under the fourteen picks: a pick brings them into sight. */
  const editRef = useRef<HTMLDivElement>(null);
  const pageRef = useRef<HTMLDivElement>(null);

  /* Each section opens at its top (the page is one scroller shared by all of them). */
  useLayoutEffect(() => { if (pageRef.current) pageRef.current.scrollTop = 0; }, [pane]);

  useEffect(() => { play('open'); }, []);

  useEffect(() => { setLogoDraft(p.serverCfg.logo.url); setLogoBad(false); }, [p.serverCfg.logo.url]);

  /* The paper note owns Escape while it is up (App.tsx leaves Escape to it): Escape = no. */
  useEffect(() => {
    if (!ask) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      e.preventDefault();
      play('close');
      setAsk(null);
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [ask]);

  const commitLogo = () => {
    const value = logoDraft.trim();

    if (value === '') { setLogoBad(false); p.editServer((c) => ({ ...c, logo: { ...c.logo, url: '' } })); return; }

    const ok = safeUrl(value) !== '';
    setLogoBad(!ok);
    if (ok) p.editServer((c) => ({ ...c, logo: { ...c.logo, url: value } }));
  };

  /** A sentence of «ما يحدث الآن» opens what it names: the page scrolls to that section. */
  const reveal = (el: HTMLElement | null, focusEl?: HTMLElement | null) => {
    const page = el?.closest('.wf-page') as HTMLElement | null;
    if (!el || !page) return;
    play('select');
    const top = el.getBoundingClientRect().top - page.getBoundingClientRect().top + page.scrollTop;
    page.scrollTo({ top: Math.max(0, top - 12 * wsFontScale()), behavior: 'smooth' });
    if (focusEl) window.setTimeout(() => focusEl.focus(), 250);
  };

  const close = () => { play('close'); p.onClose(); };
  const go = (next: Pane) => { if (next === pane) return; play('select'); setPane(next); };

  /* Picking an element from any pane jumps to the pane that can edit it -- otherwise a
     click on the HUD while the colours are open looks like it did nothing. */
  useEffect(() => {
    if (p.selected && pane !== 'elements') setPane('elements');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [p.selected]);

  useEffect(() => {
    if (!p.selected) return;
    const id = window.requestAnimationFrame(() => {
      /* only the page scrolls -- scrollIntoView would also move overflow-hidden parents (the HUD) */
      const el = editRef.current;
      const page = el?.closest('.wf-page') as HTMLElement | null;
      if (!el || !page) return;
      const top = el.getBoundingClientRect().top - page.getBoundingClientRect().top + page.scrollTop;
      page.scrollTo({ top: Math.max(0, top - 12 * wsFontScale()), behavior: 'smooth' });
    });
    return () => window.cancelAnimationFrame(id);
  }, [p.selected]);

  /* The masthead is the handle. Percent of the viewport, like everything else here, so a
     panel left near an edge stays near that edge on another resolution. */
  const onGrab = (e: ReactPointerEvent<HTMLElement>) => {
    if ((e.target as HTMLElement).closest('button')) return;

    e.preventDefault();
    const vw = window.innerWidth, vh = window.innerHeight;
    const sx = e.clientX, sy = e.clientY;
    const root = e.currentTarget.closest('.hs-root') as HTMLElement;
    const bounds = root.getBoundingClientRect();
    const gap = 16 * wsFontScale(); /* --hs-safe-gap: 0.8 kit rem = 16 design px */
    const ox = bounds.left, oy = bounds.top;

    const move = (ev: PointerEvent) => {
      /* x as a share of the centred 16:9 frame (the panel is a menu: on 21:9 / 32:9 it stays in front) */
      p.setPanelPos(
        (Math.max(gap, Math.min(vw - bounds.width - gap, ox + ev.clientX - sx)) - wsGutter()) / (vh * 16 / 9) * 100,
        Math.max(gap, Math.min(vh - bounds.height - gap, oy + ev.clientY - sy)) / vh * 100,
      );
    };
    const up = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
    };

    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
  };

  const panes: Pane[] = p.isAdmin ? [...PLAYER_PANES, 'admin'] : PLAYER_PANES;

  /* ── the admin pane's words: what every player has now, and the time choices ── */
  const srvNever = t(S('srvNever'));
  const needs = srvDraft.needs;
  const dmg = srvDraft.damage;
  const hungerMins = drainMinutes(needs.hungerRate, needs.interval);
  const thirstMins = drainMinutes(needs.thirstRate, needs.interval);
  const deathMins = deathMinutes(dmg);
  const rateFor = (mins: number) => round3((100 * needs.interval) / 60 / mins);
  const drainOk = (mins: number) => { const r = rateFor(mins); return r > 0 && r <= 25; };
  const amountFor = (mins: number) => round3((100 * dmg.interval) / 60 / mins);
  const deathOk = (mins: number) => { const a = amountFor(mins); return a >= 0.5 && a <= 25; };
  const noDrain = t(S('srvNowNoDrain'));
  const hungerPick = timeChoices(hungerMins, DRAIN_STEPS, drainOk, t, noDrain);
  const thirstPick = timeChoices(thirstMins, DRAIN_STEPS, drainOk, t, noDrain);
  const deathPick = timeChoices(deathMins, DEATH_STEPS, deathOk, t);
  const atPick = (v: number): { value: string; options: Opt[] } => {
    const options = AT_STEPS.map((n) => ({ value: String(n), label: fill(t(S('srvAt')), { v: String(n) }) }));
    const hit = options.find((o) => Number(o.value) === Math.round(v));
    if (hit) return { value: hit.value, options };
    const label = fill(t(S('srvCustom')), { v: `${Math.round(v)}%` });
    return { value: 'custom', options: [{ value: 'custom', label }, ...options] };
  };
  const hungerAtPick = atPick(dmg.hungerAt);
  const thirstAtPick = atPick(dmg.thirstAt);
  const placeWords = t(S(posKey(srvDraft.identity.x, srvDraft.identity.y)));
  const offFeatures = FEATURES.filter((f) => srvDraft.features[f.id] === false);
  const nowIdentity = srvDraft.features.identity === false ? t(S('srvNowHidden'))
    : srvDraft.logo.url !== '' ? fill(t(S('srvNowLogo')), { pos: placeWords })
      : srvDraft.name.trim() !== '' ? fill(t(S('srvNowName')), { name: srvDraft.name.trim(), pos: placeWords })
        : fill(t(S('srvNowDefault')), { pos: placeWords });
  const nowNeeds = fill(t(S('srvNowNeeds')), {
    hunger: duration(hungerMins, t, noDrain), thirst: duration(thirstMins, t, noDrain),
  });
  const nowDamage = !dmg.enabled ? t(S('srvNowDmgOff'))
    : fill(t(S(dmg.canKill ? 'srvNowDmgKill' : 'srvNowDmgSafe')), {
      h: String(Math.round(dmg.hungerAt)), t: String(Math.round(dmg.thirstAt)), death: duration(deathMins, t, srvNever),
    });
  const nowFeatures = offFeatures.length === 0 ? t(S('srvNowAllOn'))
    : fill(t(S('srvNowOff')), { list: offFeatures.map((f) => t(f.label)).join(t(S('and'))) });
  /** A starving character dying within half an hour is allowed, but it is said out loud. */
  const deathFast = dmg.enabled && dmg.canKill && isFinite(deathMins) && deathMins < 30;
  const ready: { kind: 'is-bad' | 'is-good' | 'is-wait' | ''; text: string } = logoBad
    ? { kind: 'is-bad', text: t(S('srvReadyMissing')) }
    : p.srvState === 'saved' ? { kind: 'is-good', text: t(S('srvReadySaved')) }
      : p.srvState === 'dirty' || p.srvState === 'saving' ? { kind: 'is-wait', text: t(S('srvReadyDirty')) }
        : { kind: '', text: t(S('srvReadyIdle')) };
  const fixLogo = () => reveal(idRef.current, logoRef.current);

  /* Picks for widgets the server switched off would select something that cannot be
     drawn -- so they are not offered here either. */
  const gone = new Set<WidgetId>();
  for (const [feature, ids] of Object.entries(FEATURE_WIDGETS)) {
    if (p.serverCfg.features[feature as FeatureId] === false) {
      for (const id of ids ?? []) gone.add(id);
    }
  }

  const meta = p.selected ? WIDGET_BY_ID[p.selected] : null;
  const cfg: WidgetCfg | null = p.selected ? p.settings.widgets[p.selected] : null;
  const name = (id: WidgetId) => t(WIDGET_BY_ID[id].label);

  /* An element with no colour of its own is drawn in the theme's: the circles in theirs, the
     wallet in the money colour (or its stock tones), the compass in the accent, the effects in the
     theme's paper, the rest in the text colour. The swatch shows that, and its "follow" button says
     which it is. */
  const theme = p.settings.theme;
  const followColour = (id: WidgetId): string =>
    id === 'buffs' ? DEFAULT_THEME.text
      : CORE_GROUPS.includes(WIDGET_BY_ID[id].group) ? theme.core
        : id === 'money' ? (theme.money || theme.text)
          : id === 'compass' ? theme.accent : theme.text;
  const followLabel = (id: WidgetId): string =>
    id === 'buffs' ? 'fieldDefault'
      : CORE_GROUPS.includes(WIDGET_BY_ID[id].group) ? 'inheritCore'
        : id === 'money' ? 'inheritMoney' : 'inheritColour';

  const saveLabel =
    p.saving === 'saving' ? t(S('saving'))
      : p.saving === 'saved' ? t(S('saved'))
        : p.saving === 'dirty' ? t(S('dirty')) : t(S('save'));

  const shareCode = encodeShare(profileFrom(p.settings, t('profile.shared')));

  /* ⚠️ execCommand, not navigator.clipboard. The async clipboard API needs a secure
     context and a permission that nui:// does not have, so it rejects silently in CEF.
     Selecting the field and copying it is the old way and it is the one that works --
     and the field stays selected either way, so Ctrl+C is always the fallback. */
  const copyShare = () => {
    const el = shareRef.current;
    if (!el) return;

    el.select();
    el.setSelectionRange(0, el.value.length);

    let ok = false;
    try { ok = document.execCommand('copy'); } catch { ok = false; }

    play(ok ? 'select' : 'deny');
    setCodeNote(ok ? 'copied' : '');
    window.setTimeout(() => setCodeNote((n) => (n === 'copied' ? '' : n)), 1600);
  };

  const applyCode = () => {
    const ok = p.importCode(code);
    play(ok ? 'select' : 'deny');
    setCodeNote(ok ? 'ok' : 'bad');
    if (ok) setCode('');
    window.setTimeout(() => setCodeNote(''), 2200);
  };

  /* The slot actions act on the chosen slot only. */
  const chosenSlot = slotSel !== null ? p.settings.profiles[slotSel] : null;
  const confirmAsk = () => {
    if (!ask) return;
    play('select');
    if (ask.kind === 'resetAll') p.resetAll();
    else p.clearProfile(ask.slot);
    setAsk(null);
  };

  const wrapStyle = (i: number) => ({ '--i': i } as CSSProperties);
  const rootStyle: CSSProperties | undefined = docked ? undefined : {
    left: `clamp(var(--hs-safe-gap), calc(var(--ws-gutter) + ${+(pos.x * 16 / 9).toFixed(4)}vh), calc(100vw - var(--hs-panel-width) - var(--hs-safe-gap)))`,
    top: `clamp(var(--hs-safe-gap), ${pos.y}vh, calc(100vh - var(--hs-panel-height) - var(--hs-safe-gap)))`,
  };

  return (
    <div className={cls('wf', 'hs-stage', rtl && 'is-rtl')}>
      <div className={cls('hs-root', docked && 'is-docked', ask && 'is-dim')} style={rootStyle}>
        {/* ── the masthead: the name of the board, and the handle ───────────── */}
        <header className="wf-mast wf-in" onPointerDown={onGrab} style={wrapStyle(0)}>
          <span className="wf-mark">{t(S('title'))}</span>
          <span className="wf-mast-rule" />
          <button type="button" className="hs-close" onClick={close} title={t(S('close'))} aria-label={t(S('close'))}>
            <CloseIcon />
          </button>
        </header>

        {/* ── the head card: the open section ───────────────────────────────── */}
        <div className={cls('wf-wrap', 'wf-head-wrap', 'hs-head-wrap', 'wf-in', focus === 'head' && 'is-focus')}
          style={wrapStyle(1)} onMouseEnter={() => setFocus('head')}>
          <div className="wf-tick" />
          <div className="wf-card wf-head"><div className="wf-card-body">
            <h2 className="wf-h">{pane === 'elements' && meta ? name(meta.id) : t(S('pane_' + pane))}</h2>
            <p className="wf-sub">{t(S('sub'))}</p>
          </div></div>
        </div>

        {/* ── the page card: the sections as tabs, the open one under them ──── */}
        <div className={cls('wf-wrap', 'hs-page-wrap', 'wf-in', focus === 'page' && 'is-focus')}
          style={wrapStyle(2)} onMouseEnter={() => setFocus('page')}>
          <div className="wf-tick" />
          <div className="wf-card"><div className="wf-card-body">
            <div className="wf-tabs hs-tabs" role="tablist">
              {panes.map((key) => (
                <button key={key} type="button" role="tab" aria-selected={pane === key}
                  className={cls('wf-tab', pane === key && 'is-active')}
                  onMouseEnter={() => play('hover')}
                  onClick={() => go(key)}>
                  {t(S('pane_' + key))}
                </button>
              ))}
            </div>

            <div className="wf-page is-scroll" ref={pageRef}>
              {pane === 'elements' && (
                <>
                  <Section title={t(S('pick'))}>
                    <div className="hs-picks">
                      {GROUP_ORDER.map((group) => {
                        /* ⚠️ The server's name-and-logo block is not in this list on purpose.
                           What it says and where it sits are the admin's, and both live in
                           the Admin section -- offering a pick for it here would let a
                           player move branding they cannot change the content of. */
                        const rows = WIDGETS.filter((w) =>
                          w.group === group && !gone.has(w.id) && w.id !== 'server');
                        if (!rows.length) return null;

                        return (
                          <div className="hs-pick-group" key={group}>
                            <span className="wf-label">{t(GROUP_LABEL[group])}</span>
                            <div className="hs-pick-grid">
                              {rows.map((w) => {
                                const c = p.settings.widgets[w.id];
                                return (
                                  <button key={w.id} type="button"
                                    className={cls('wf-btn', 'hs-pick', p.selected === w.id && 'is-chosen', !c.show && 'is-off')}
                                    onMouseEnter={() => play('hover')}
                                    onClick={() => { play('select'); p.select(w.id); }}>
                                    <span>{name(w.id)}</span>
                                    {(!c.show || c.locked) && (
                                      <i className="hs-pick-mark">{c.show ? '⌧' : '◌'}</i>
                                    )}
                                  </button>
                                );
                              })}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </Section>

                  {meta && cfg ? (
                    <div ref={editRef} className="hs-edit">
                    <Section title={name(meta.id)}>
                      <Switches two>
                        <Toggle label={t(S('show'))} on={cfg.show} onChange={(v) => p.patch(meta.id, { show: v })} />
                        <Toggle label={t(S('lock'))} on={cfg.locked} onChange={(v) => p.patch(meta.id, { locked: v })} />
                      </Switches>

                      <div className="hs-inline">
                        <span className="wf-label">{t(S('position'))}</span>
                        <span className="hs-pos">{cfg.x.toFixed(1)} · {cfg.y.toFixed(1)}</span>
                        <button type="button" className="wf-btn"
                          onClick={() => { play('select'); p.resetWidget(meta.id); }}>
                          <ResetIcon />{t(S('resetOne'))}
                        </button>
                      </div>

                      <Slider label={t(S('size'))} value={cfg.scale} min={0.5} max={2} step={0.01}
                        format={(v) => `${Math.round(v * 100)}%`}
                        onChange={(v) => p.patch(meta.id, { scale: v })} />
                      <Slider label={t(S('clarity'))} value={cfg.opacity} min={0.15} max={1} step={0.01}
                        format={(v) => `${Math.round(v * 100)}%`}
                        onChange={(v) => p.patch(meta.id, { opacity: v })} />

                      {meta.tint && (
                        <div className="hs-fieldrow">
                          <span className="wf-label">{t(S('colour'))}</span>
                          <ColorField
                            value={cfg.color ?? followColour(meta.id)}
                            onChange={(hex) => p.patch(meta.id, { color: hex })}
                            inherit={{
                              active: cfg.color === null,
                              label: t(S(followLabel(meta.id))),
                              onPick: () => p.patch(meta.id, { color: null }),
                            }}
                          />
                        </div>
                      )}

                      {/* The wallet's rows, each its own colour -- the same fields as the Colours pane,
                          offered here too because this is where a player looking at the wallet is. */}
                      {meta.id === 'money' && (
                        <>
                          <h4 className="wf-sec">{t(S('rowColours'))}</h4>
                          <ul className="hs-fields is-compact">
                            {THEME_FIELDS.filter((f) => f.empty === 'wallet').map((field) => (
                              <ThemeColour key={field.key} field={field} settings={p.settings} t={t}
                                setTheme={p.setTheme} preview={p.previewState} />
                            ))}
                          </ul>
                        </>
                      )}

                      {meta.media && (
                        <>
                          <MediaFields
                            id={meta.id as MediaId}
                            cfg={p.settings.media[meta.id as MediaId]}
                            t={t}
                            onChange={p.setMedia}
                          />
                          {meta.id === 'server' && <p className="wf-note-line">{t(S('logoNote'))}</p>}
                        </>
                      )}

                      {/* Only a gauge has a value to appear below or warn about. */}
                      {meta.gauge && (
                        <>
                          <Segmented<Visibility>
                            label={t(S('whenVisible'))}
                            value={cfg.visibility}
                            options={[
                              { value: 'auto', label: t(S('vAuto')) },
                              { value: 'always', label: t(S('vAlways')) },
                              { value: 'below', label: t(S('vBelow')) },
                            ]}
                            onChange={(v) => p.patch(meta.id, { visibility: v })}
                          />
                          {cfg.visibility === 'below' && (
                            <Slider label={t(S('below'))} value={cfg.showBelow} min={5} max={100} step={1}
                              format={(v) => `${Math.round(v)}%`}
                              onChange={(v) => p.patch(meta.id, { showBelow: v })} />
                          )}

                          <Switches>
                            <Toggle
                              label={t(S('ownLimits'))}
                              on={cfg.warn !== null || cfg.danger !== null}
                              onChange={(v) => p.patch(meta.id, v
                                ? { warn: 40, danger: 20 }
                                : { warn: null, danger: null })}
                            />
                          </Switches>
                          {(cfg.warn !== null || cfg.danger !== null) && (
                            <>
                              <Slider label={t(S('warnAt'))} value={cfg.warn ?? 40} min={2} max={99} step={1}
                                format={(v) => `${Math.round(v)}%`}
                                onChange={(v) => p.patch(meta.id, { warn: v })} />
                              <Slider label={t(S('dangerAt'))} value={cfg.danger ?? 20} min={1} max={98} step={1}
                                format={(v) => `${Math.round(v)}%`}
                                onChange={(v) => p.patch(meta.id, { danger: v })} />
                            </>
                          )}
                        </>
                      )}
                    </Section>
                    </div>
                  ) : (
                    <p className="wf-empty">{t(S('nothing'))}</p>
                  )}
                </>
              )}

              {pane === 'colours' && (
                <>
                  <Section title={t(S('palettes'))}>
                    <div className="hs-presets">
                      {THEME_PRESETS.map((preset) => (
                        <button key={preset.id} type="button" className="wf-btn hs-preset"
                          onMouseEnter={() => play('hover')}
                          onClick={() => { play('select'); p.setTheme(preset.theme); }}>
                          <span className="hs-preset-strip">
                            <i style={{ background: preset.theme.accent }} />
                            <i style={{ background: preset.theme.text }} />
                            <i style={{ background: preset.theme.warn }} />
                            <i style={{ background: preset.theme.danger }} />
                          </span>
                          <span className="hs-preset-name">{t(preset.label)}</span>
                        </button>
                      ))}
                    </div>
                  </Section>

                  {/* ★ Three groups: the general colours, the circles and every state they can show
                      (one field each -- a state is the circle changing colour), and the wallet with a
                      field per row. */}
                  {COLOUR_GROUPS.map((group) => (
                    <Section key={group} title={t(S('colGroup_' + group))}
                      note={group === 'states'
                        ? t(S(p.settings.shape.dangerWins ? 'statesOrderDanger' : 'statesOrderEffect'))
                        : group === 'wallet' ? t(S('walletOrder')) : undefined}>
                      <ul className="hs-fields">
                        {THEME_FIELDS.filter((f) => f.group === group).map((field) => (
                          <ThemeColour key={field.key} field={field} settings={p.settings} t={t}
                            setTheme={p.setTheme} preview={p.previewState} />
                        ))}
                      </ul>
                      {group === 'states' && (
                        <Switches>
                          <Toggle label={t(S('dangerWins'))} on={p.settings.shape.dangerWins}
                            onChange={(v) => p.setShape({ dangerWins: v })} />
                        </Switches>
                      )}
                    </Section>
                  ))}
                </>
              )}

              {pane === 'shape' && (
                <Section note={t(S('shapeNote'))}>
                  <Slider label={t(S('ring'))} value={p.settings.shape.ring} min={3} max={16} step={0.5}
                    format={(v) => v.toFixed(1)} onChange={(v) => p.setShape({ ring: v })} />
                  <Slider label={t(S('disc'))} value={p.settings.shape.disc} min={0} max={1} step={0.01}
                    format={(v) => `${Math.round(v * 100)}%`} onChange={(v) => p.setShape({ disc: v })} />
                  <Slider label={t(S('icon'))} value={p.settings.shape.icon} min={0.4} max={0.85} step={0.01}
                    format={(v) => `${Math.round(v * 100)}%`} onChange={(v) => p.setShape({ icon: v })} />
                  <Switches>
                    <Toggle label={t(S('motion'))} on={p.settings.shape.motion}
                      onChange={(v) => p.setShape({ motion: v })} />
                  </Switches>
                </Section>
              )}

              {pane === 'display' && (
                <Section>
                  <Segmented<MapMode> label={t(S('mapFoot'))} value={p.settings.world.onFoot}
                    options={[
                      { value: 'server', label: t(S('mServer')) },
                      { value: 'off', label: t(S('mOff')) },
                      { value: 'map', label: t(S('mMap')) },
                      { value: 'compass', label: t(S('mCompass')) },
                    ]}
                    onChange={(v) => p.setWorld({ onFoot: v })} />

                  <Segmented<MapMode> label={t(S('mapMount'))} value={p.settings.world.mounted}
                    options={[
                      { value: 'server', label: t(S('mServer')) },
                      { value: 'off', label: t(S('mOff')) },
                      { value: 'map', label: t(S('mMap')) },
                      { value: 'compass', label: t(S('mCompass')) },
                    ]}
                    onChange={(v) => p.setWorld({ mounted: v })} />

                  <Slider label={t(S('hudSize'))} value={p.settings.scale} min={0.6} max={1.8} step={0.01}
                    format={(v) => `${Math.round(v * 100)}%`} onChange={p.setScale} />
                </Section>
              )}

              {pane === 'layout' && (
                <>
                  <Section>
                    <Switches>
                      <Toggle label={t(S('snap'))} on={p.settings.grid.snap} onChange={(v) => p.setGrid({ snap: v })} />
                    </Switches>
                    <Slider label={t(S('snapSize'))} value={p.settings.grid.size} min={0.1} max={3} step={0.1}
                      format={(v) => `${v.toFixed(1)}%`} onChange={(v) => p.setGrid({ size: v })} />
                    <Switches>
                      <Toggle label={t(S('guides'))} on={p.settings.grid.guides} onChange={(v) => p.setGrid({ guides: v })} />
                    </Switches>
                    <p className="wf-note-line">{t(S('tips'))}</p>
                  </Section>

                  <Section title={t(S('restore'))}>
                    <div className="wf-btns">
                      <button type="button" className="wf-btn"
                        onClick={() => { play('select'); p.resetPositions(); }}>
                        <ResetIcon />{t(S('resetPos'))}
                      </button>
                      <button type="button" className="wf-btn is-danger"
                        onClick={() => { play('select'); setAsk({ kind: 'resetAll' }); }}>
                        <ResetIcon />{t(S('resetAll'))}
                      </button>
                    </div>
                  </Section>
                </>
              )}

              {pane === 'profiles' && (
                <>
                  <Section>
                    <div className="wf-rows hs-slots">
                      {Array.from({ length: PROFILE_SLOTS }, (_, i) => {
                        const slot = p.settings.profiles[i];
                        return (
                          <div key={i} role="button" tabIndex={0}
                            className={cls('wf-row', 'hs-slot', slotSel === i && 'is-chosen', !slot && 'is-empty')}
                            onMouseEnter={() => play('hover')}
                            onClick={() => { play('select'); setSlotSel(i); }}
                            onKeyDown={(e) => { if (e.key === 'Enter') { play('select'); setSlotSel(i); } }}>
                            <span className="hs-slot-num">{i + 1}</span>
                            <span className="wf-row-main"><span className="wf-row-name">{slot ? slot.name : t(S('slotEmpty'))}</span></span>
                          </div>
                        );
                      })}
                    </div>
                    <div className="wf-btns">
                      <button type="button" className="wf-btn" aria-disabled={chosenSlot ? undefined : 'true'}
                        onClick={() => { if (slotSel === null || !chosenSlot) return; play('select'); p.applyProfile(slotSel); }}>
                        {t(S('slotApply'))}
                      </button>
                      <button type="button" className="wf-btn" aria-disabled={slotSel !== null ? undefined : 'true'}
                        onClick={() => { if (slotSel === null) return; play('select'); p.saveProfile(slotSel, `${t('profile.layout')} ${slotSel + 1}`); }}>
                        {t(S('slotSave'))}
                      </button>
                      <button type="button" className="wf-btn is-danger" aria-disabled={chosenSlot ? undefined : 'true'}
                        onClick={() => { if (slotSel === null || !chosenSlot) return; play('select'); setAsk({ kind: 'clearSlot', slot: slotSel }); }}>
                        {t(S('slotClear'))}
                      </button>
                    </div>
                    {slotSel === null && <p className="wf-note-line">{t(S('pickSlot'))}</p>}
                  </Section>

                  <Section title={t(S('shareOut'))}>
                    <div className="hs-code-row">
                      <input ref={shareRef} className="wf-input hs-code" readOnly value={shareCode}
                        onFocus={(e) => e.currentTarget.select()} spellCheck={false} />
                      <button type="button" className="wf-btn" onClick={copyShare}>
                        {codeNote === 'copied' ? t(S('shareCopied')) : t(S('shareCopy'))}
                      </button>
                    </div>
                  </Section>

                  <Section title={t(S('shareIn'))}>
                    <div className="hs-code-row">
                      <input className={cls('wf-input', 'hs-code', codeNote === 'bad' && 'is-invalid')} value={code} spellCheck={false}
                        onChange={(e) => { setCode(e.target.value); setCodeNote(''); }} />
                      <button type="button" className="wf-btn" aria-disabled={code.trim() === '' ? 'true' : undefined}
                        onClick={() => { if (code.trim() !== '') applyCode(); }}>{t(S('shareApply'))}</button>
                    </div>
                    {codeNote === 'bad' && <p className="wf-error">{t(S('shareBad'))}</p>}
                    {codeNote === 'ok' && <p className="wf-note-line is-good">{t(S('shareOk'))}</p>}
                  </Section>
                </>
              )}

              {pane === 'admin' && p.isAdmin && (
                <>
                  <p className="hs-warnline">{t(S('adminOnly'))}</p>

                  {/* ★ What every player has now, in sentences. Each one opens the section
                      it names -- the words are the way in, the controls follow them. */}
                  <Section title={t(S('srvNow'))}>
                    <ul className="hs-story">
                      <li><button type="button" className="hs-say" onClick={() => reveal(idRef.current)}>{nowIdentity}</button></li>
                      <li><button type="button" className="hs-say" onClick={() => reveal(needsRef.current)}>{nowNeeds}</button></li>
                      <li><button type="button" className="hs-say" onClick={() => reveal(dmgRef.current)}>{nowDamage}</button></li>
                      <li><button type="button" className="hs-say" onClick={() => reveal(featRef.current)}>{nowFeatures}</button></li>
                    </ul>
                  </Section>

                  <div ref={idRef}>
                    <Section title={t(S('srvIdentity'))}>
                      <label className="wf-field hs-field-block">
                        <span className="wf-label">{t(S('srvName'))}</span>
                        <input
                          className="wf-input"
                          value={srvDraft.name}
                          maxLength={48}
                          spellCheck={false}
                          placeholder={t(S('srvNamePh'))}
                          onChange={(e) => editIdentity({ name: e.target.value })}
                        />
                      </label>

                      <label className="wf-field hs-field-block">
                        <span className="wf-label">{t(S('srvLogo'))}</span>
                        <input
                          ref={logoRef}
                          className={cls('wf-input', 'hs-code', logoBad && 'is-invalid')}
                          value={logoDraft}
                          spellCheck={false}
                          placeholder="https://..."
                          onChange={(e) => setLogoDraft(e.target.value)}
                          onBlur={commitLogo}
                          onKeyDown={(e) => { if (e.key === 'Enter') commitLogo(); }}
                        />
                      </label>
                      {logoBad ? <p className="wf-error">{t(S('imageBad'))}</p> : <p className="wf-note-line">{t(S('srvLogoNote'))}</p>}
                      {srvDraft.logo.url !== '' && (
                        <div className="wf-btns">
                          <button type="button" className="wf-btn is-danger"
                            onClick={() => { play('select'); editIdentity({ logo: { ...srvDraft.logo, url: '' } }); }}>
                            {t(S('imageClear'))}
                          </button>
                        </div>
                      )}

                      {/* Placement travels with the branding: the admin drags it once and
                          every player has it there. Said as a place; the numbers are in the fold. */}
                      <div className="hs-inline">
                        <span className="wf-label">{t(S('srvPlace'))}</span>
                        <span className="hs-pos hs-pos-words">{placeWords}</span>
                        <button type="button" className="wf-btn"
                          onClick={() => { play('select'); editIdentity({ identity: { x: 98.2, y: 2, scale: 1, opacity: 1 } }); }}>
                          <ResetIcon />{t(S('restore'))}
                        </button>
                      </div>
                      <p className="wf-note-line">{t(S('srvIdDrag'))}</p>

                      <Fold open={adv.id} onToggle={() => setAdv((a) => ({ ...a, id: !a.id }))}
                        label={t(S('advanced'))} note={t(S('advancedNote'))}>
                        {srvDraft.logo.url !== '' && (
                          <>
                            <Slider label={t(S('imageW'))} value={srvDraft.logo.width} min={2} max={160} step={1}
                              format={(v) => String(Math.round(v))}
                              onChange={(v) => editIdentity({ logo: { ...srvDraft.logo, width: v } })} />
                            <Slider label={t(S('imageH'))} value={srvDraft.logo.height} min={0} max={160} step={1}
                              format={(v) => (v <= 0 ? t(S('imageAuto')) : String(Math.round(v)))}
                              onChange={(v) => editIdentity({ logo: { ...srvDraft.logo, height: v } })} />
                          </>
                        )}
                        <Slider label={t(S('srvIdScale'))} value={srvDraft.identity.scale} min={0.4} max={3} step={0.01}
                          format={(v) => `${Math.round(v * 100)}%`}
                          onChange={(v) => editIdentity({ identity: { ...srvDraft.identity, scale: v } })} />
                        <Slider label={t(S('clarity'))} value={srvDraft.identity.opacity} min={0.15} max={1} step={0.01}
                          format={(v) => `${Math.round(v * 100)}%`}
                          onChange={(v) => editIdentity({ identity: { ...srvDraft.identity, opacity: v } })} />
                        <div className="hs-inline">
                          <span className="wf-label">{t(S('position'))}</span>
                          <span className="hs-pos">{srvDraft.identity.x.toFixed(1)} · {srvDraft.identity.y.toFixed(1)}</span>
                        </div>
                      </Fold>
                    </Section>
                  </div>

                  {/* ★ Every rate is chosen as what it means: the time from full to empty. The
                      choice is turned back into the stored rate (rateFor), so the server keeps
                      the same numbers and the same clamps. */}
                  <div ref={needsRef}>
                    <Section title={t(S('srvNeeds'))}>
                      <Segmented label={t(S('srvHungerEmpty'))} value={hungerPick.value} options={hungerPick.options}
                        onChange={(v) => { if (v !== 'custom') editNeeds({ hungerRate: v === 'never' ? 0 : rateFor(Number(v)) }); }} />
                      <Segmented label={t(S('srvThirstEmpty'))} value={thirstPick.value} options={thirstPick.options}
                        onChange={(v) => { if (v !== 'custom') editNeeds({ thirstRate: v === 'never' ? 0 : rateFor(Number(v)) }); }} />

                      <Fold open={adv.needs} onToggle={() => setAdv((a) => ({ ...a, needs: !a.needs }))}
                        label={t(S('advanced'))} note={t(S('advancedNote'))}>
                        <Slider label={t(S('srvHungerRate'))} value={needs.hungerRate}
                          min={0} max={25} step={0.1} format={(v) => v.toFixed(2)}
                          onChange={(v) => editNeeds({ hungerRate: v })} />
                        <Slider label={t(S('srvThirstRate'))} value={needs.thirstRate}
                          min={0} max={25} step={0.1} format={(v) => v.toFixed(2)}
                          onChange={(v) => editNeeds({ thirstRate: v })} />
                        <Slider label={t(S('srvInterval'))} value={needs.interval}
                          min={5} max={600} step={5} format={(v) => `${Math.round(v)} ${t(S('perSec'))}`}
                          onChange={(v) => editNeeds({ interval: v })} />
                      </Fold>
                    </Section>
                  </div>

                  <div ref={dmgRef}>
                    <Section title={t(S('srvDamage'))}>
                      <Switches>
                        <Toggle label={t(S('srvDmgOn'))} on={dmg.enabled}
                          onChange={(v) => editDamage({ enabled: v })} />
                      </Switches>

                      {dmg.enabled && (
                        <>
                          <Segmented label={t(S('srvHungerAt'))} value={hungerAtPick.value} options={hungerAtPick.options}
                            onChange={(v) => { if (v !== 'custom') editDamage({ hungerAt: Number(v) }); }} />
                          <Segmented label={t(S('srvThirstAt'))} value={thirstAtPick.value} options={thirstAtPick.options}
                            onChange={(v) => { if (v !== 'custom') editDamage({ thirstAt: Number(v) }); }} />
                          <Switches>
                            <Toggle label={t(S('srvCanKill'))} on={dmg.canKill}
                              onChange={(v) => editDamage({ canKill: v })} />
                          </Switches>
                          {dmg.canKill
                            ? <Segmented label={t(S('srvDeathAfter'))} value={deathPick.value} options={deathPick.options}
                                onChange={(v) => { if (v !== 'custom') editDamage({ amount: amountFor(Number(v)) }); }} />
                            : <p className="wf-note-line">{t(S('srvCanKillOff'))}</p>}

                          <Fold open={adv.dmg} onToggle={() => setAdv((a) => ({ ...a, dmg: !a.dmg }))}
                            label={t(S('advanced'))} note={t(S('advancedNote'))}>
                            <Slider label={t(S('srvHungerAt'))} value={dmg.hungerAt}
                              min={0} max={99} step={1} format={(v) => `${Math.round(v)}%`}
                              onChange={(v) => editDamage({ hungerAt: v })} />
                            <Slider label={t(S('srvThirstAt'))} value={dmg.thirstAt}
                              min={0} max={99} step={1} format={(v) => `${Math.round(v)}%`}
                              onChange={(v) => editDamage({ thirstAt: v })} />
                            <Slider label={t(S('srvAmount'))} value={dmg.amount}
                              min={0.5} max={25} step={0.5} format={(v) => `${v.toFixed(1)}%`}
                              onChange={(v) => editDamage({ amount: v })} />
                            <Slider label={t(S('srvDmgInterval'))} value={dmg.interval}
                              min={3} max={300} step={1} format={(v) => `${Math.round(v)} ${t(S('perSec'))}`}
                              onChange={(v) => editDamage({ interval: v })} />
                          </Fold>
                        </>
                      )}
                    </Section>
                  </div>

                  <div ref={featRef}>
                    <Section title={t(S('srvFeatures'))} note={t(S('srvFeaturesNote'))}>
                      <Switches two>
                        {FEATURES.map((f) => (
                          <Toggle key={f.id} label={t(f.label)}
                            on={srvDraft.features[f.id] !== false}
                            onChange={(v) => editFeature(f.id, v)} />
                        ))}
                      </Switches>
                    </Section>
                  </div>

                  {/* ★ The readiness line: what the send will do, or what stops it, with «أصلحه»
                      taking the admin to the field. Red only for the one thing that is wrong. */}
                  <Section>
                    <div className={cls('hs-ready', ready.kind)}>
                      <i className="hs-ready-dot" />
                      <span className="hs-ready-text">{ready.text}</span>
                      {logoBad && (
                        <button type="button" className="wf-btn hs-ready-fix" onClick={fixLogo}>{t(S('fixIt'))}</button>
                      )}
                    </div>
                    {deathFast && <p className="wf-note-line">{fill(t(S('srvReadyFast')), { death: duration(deathMins, t, srvNever) })}</p>}
                    <button type="button"
                      className={cls('hs-btn', 'is-main', 'is-wide', p.srvState === 'saved' && 'is-done')}
                      disabled={p.srvState === 'saving'}
                      onClick={() => { play('select'); p.publishServer(); }}>
                      {p.srvState === 'saved' ? t(S('srvSaved'))
                        : p.srvState === 'saving' ? t(S('saving'))
                          : p.srvState === 'dirty' ? t(S('srvSending')) : t(S('srvSave'))}
                    </button>
                    <p className="wf-note-line">{t(S('srvLiveNote'))}</p>
                    <div className="hs-keys">
                      <span><kbd className="hs-key">Esc</kbd>{t(S('keyClose'))}</span>
                      <span><kbd className="hs-key">Enter</kbd>{t(S('keyCommit'))}</span>
                    </div>
                  </Section>
                </>
              )}
            </div>
          </div></div>
        </div>

        {/* ── the actions strip: save (the red mark band) and close ──────────── */}
        <div className={cls('wf-wrap', 'hs-actions-wrap', 'wf-in', focus === 'actions' && 'is-focus')}
          style={wrapStyle(3)} onMouseEnter={() => setFocus('actions')}>
          <div className="wf-tick" />
          <div className="wf-card"><div className="wf-card-body hs-actbar">
            <button type="button"
              className={cls('hs-btn', 'is-main', p.saving === 'saved' && 'is-done')}
              disabled={p.saving === 'saving'}
              onClick={() => { play('select'); p.onSave(); }}>
              {saveLabel}
            </button>
            <button type="button" className="hs-btn" onClick={close}>{t(S('close'))}</button>
          </div></div>
        </div>

        {/* ── are you sure? the paper note, the board dimmed behind it ───────── */}
        {ask && (
          <div className="wf-note" role="dialog" aria-modal="true"
            onMouseDown={(e) => { if (e.target === e.currentTarget) setAsk(null); }}>
            <div className="wf-note-plate">
              <p className="wf-note-kicker">{t(S('confirmKicker'))}</p>
              <p className="wf-note-q">{t(S(ask.kind === 'resetAll' ? 'resetAllQ' : 'clearSlotQ'))}</p>
              <p className="wf-note-sub">{t(S(ask.kind === 'resetAll' ? 'resetAllSub' : 'clearSlotSub'))}</p>
              <div className="wf-note-row">
                <button type="button" className="wf-choice" onClick={confirmAsk}>{t(S('yes'))}</button>
                <button type="button" className="wf-choice" onClick={() => { play('close'); setAsk(null); }}>{t(S('no'))}</button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
