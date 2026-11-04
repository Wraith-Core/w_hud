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
 *   Three changes fixed that, and they are the shape of this file:
 *
 *   ★ A rail down the side instead of tabs across the top. Six sections do not fit in a
 *     row without shrinking the words to nothing, and a rail grows to a seventh without
 *     any of them getting smaller.
 *
 *   ★ The element list is a grid of chips, not rows. Fourteen rows with two buttons each
 *     is twenty-eight controls competing for attention before you have chosen anything.
 *     Fourteen chips is one control: pick a thing. Its buttons appear once it is picked.
 *
 *   ★ One place shows properties -- the section itself, not a permanent strip underneath.
 *     The pinned inspector meant two things were always current at once (a tab and an
 *     element), and the panel never looked settled.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from 'react';
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

/* ── icons ──────────────────────────────────────────────────────────────────── */
const I = {
  elements: () => (<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"><path d="M12 3 3 7.5 12 12l9-4.5L12 3z" /><path d="m3 12 9 4.5L21 12" /><path d="m3 16.5 9 4.5 9-4.5" /></svg>),
  colours: () => (<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"><path d="M12 3s6 6.4 6 10.3A6 6 0 0 1 6 13.3C6 9.4 12 3 12 3z" /></svg>),
  shape: () => (<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7"><circle cx="12" cy="12" r="8.6" /><circle cx="12" cy="12" r="3.4" /></svg>),
  display: () => (<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"><path d="M9 4.5 3 7v12.5l6-2.5 6 2.5 6-2.5V4.5L15 7 9 4.5z" /><path d="M9 4.5V17M15 7v12.5" /></svg>),
  layout: () => (<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7"><rect x="3.5" y="3.5" width="17" height="17" rx="1.6" /><path d="M9.2 3.5v17M14.8 3.5v17M3.5 9.2h17M3.5 14.8h17" /></svg>),
  profiles: () => (<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"><path d="M6.5 3.5h11a1 1 0 0 1 1 1v16l-6.5-4-6.5 4v-16a1 1 0 0 1 1-1z" /></svg>),
  admin: () => (<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"><path d="M12 3 5 6v6c0 4.3 2.9 7.7 7 9 4.1-1.3 7-4.7 7-9V6l-7-3z" /><path d="M9.4 12.2l1.9 1.9 3.6-3.8" /></svg>),
};

const ResetIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round">
    <path d="M4 12a8 8 0 1 0 2.6-5.9" /><path d="M4 4v4.4h4.4" />
  </svg>
);

const CloseIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <path d="M6 6l12 12M18 6 6 18" />
  </svg>
);

/* ── building blocks ────────────────────────────────────────────────────────── */

function Slider({ label, value, min, max, step, format, onChange }: {
  label: string; value: number; min: number; max: number; step: number;
  format?: (v: number) => string; onChange: (v: number) => void;
}) {
  return (
    <label className="hs-slider">
      <span className="hs-slider-top">
        <span className="hs-slider-label">{label}</span>
        <span className="hs-slider-val">{format ? format(value) : value.toFixed(2)}</span>
      </span>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={(e) => onChange(Number(e.target.value))} />
    </label>
  );
}

function Toggle({ label, on, onChange }: { label: string; on: boolean; onChange: (v: boolean) => void }) {
  return (
    <button type="button" className={'hs-toggle' + (on ? ' is-on active' : '')}
      onClick={() => { play('select'); onChange(!on); }}>
      <i className="hs-toggle-track"><i className="hs-toggle-knob" /></i>
      <span>{label}</span>
    </button>
  );
}

/** A row of exclusive choices -- the shape a two-to-four-way switch should take. */
function Segmented<T extends string>({ label, value, options, onChange }: {
  label?: string; value: T;
  options: Array<{ value: T; label: string }>;
  onChange: (v: T) => void;
}) {
  return (
    <div className="hs-seg-wrap">
      {label && <span className="hs-seg-label">{label}</span>}
      <div className="hs-seg">
        {options.map((o) => (
          <button key={o.value} type="button"
            className={'hs-seg-btn wst-tab' + (o.value === value ? ' is-on active' : '')}
            onClick={() => { play('select'); onChange(o.value); }}>
            {o.label}
          </button>
        ))}
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
      <label className="hs-urlrow">
        <span>{t(S('imageUrl'))}</span>
        <input
          className="hs-code wst-input"
          value={draft}
          spellCheck={false}
          placeholder="https://..."
          onChange={(e) => { setDraft(e.target.value); setBad(false); }}
          onBlur={commit}
          onKeyDown={(e) => { if (e.key === 'Enter') commit(); }}
        />
      </label>
      <p className={'hs-note' + (bad ? ' is-bad' : '')}>{bad ? t(S('imageBad')) : t(S('imageHint'))}</p>

      {cfg.url !== '' && (
        <>
          <Slider label={t(S('imageW'))} value={cfg.width} min={2} max={160} step={1}
            format={(v) => String(Math.round(v))}
            onChange={(v) => onChange(id, { width: v })} />
          <Slider label={t(S('imageH'))} value={cfg.height} min={0} max={160} step={1}
            format={(v) => (v <= 0 ? t(S('imageAuto')) : String(Math.round(v)))}
            onChange={(v) => onChange(id, { height: v })} />
          <button type="button" className="hs-linkbtn wst-button is-warn danger"
            onClick={() => { play('select'); onChange(id, { url: '' }); }}>
            {t(S('imageClear'))}
          </button>
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
    <section className="hs-section">
      {title && <h3 className="hs-section-title wst-section-title"><span>{title}</span></h3>}
      {children}
      {note && <p className="hs-note">{note}</p>}
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
  return `${h} ${t(S('hour'))} ${m} ${t(S('minute'))}`;
}
const GROUP_ORDER: WidgetGroup[] = ['status', 'horse', 'pet', 'info', 'nav', 'media'];
const COLOUR_GROUPS: ThemeGroup[] = ['base', 'states', 'wallet'];
/** The circles: an element of these with no colour of its own follows the circles' colour. */
const CORE_GROUPS: WidgetGroup[] = ['status', 'horse', 'pet'];

export function SettingsPanel(p: PanelProps) {
  const { t } = useI18n();
  const [pane, setPane] = useState<Pane>('elements');
  const [code, setCode] = useState('');
  const [codeNote, setCodeNote] = useState<'' | 'ok' | 'bad' | 'copied'>('');

  /* The logo link keeps a draft while it is being typed, for the reason MediaFields does:
     checking a half-typed URL fails, and a failed check would wipe it mid-word. */
  const [logoDraft, setLogoDraft] = useState(p.serverCfg.logo.url);
  const [logoBad, setLogoBad] = useState(false);

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
  const shareRef = useRef<HTMLInputElement>(null);

  useEffect(() => { play('open'); }, []);

  useEffect(() => { setLogoDraft(p.serverCfg.logo.url); setLogoBad(false); }, [p.serverCfg.logo.url]);

  const commitLogo = () => {
    const value = logoDraft.trim();

    if (value === '') { setLogoBad(false); p.editServer((c) => ({ ...c, logo: { ...c.logo, url: '' } })); return; }

    const ok = safeUrl(value) !== '';
    setLogoBad(!ok);
    if (ok) p.editServer((c) => ({ ...c, logo: { ...c.logo, url: value } }));
  };

  const close = () => { play('close'); p.onClose(); };
  const go = (next: Pane) => { play('select'); setPane(next); };

  /* Picking an element from any pane jumps to the pane that can edit it -- otherwise a
     click on the HUD while the colours are open looks like it did nothing. */
  useEffect(() => {
    if (p.selected && pane !== 'elements') setPane('elements');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [p.selected]);

  /* The header is the handle. Percent of the viewport, like everything else here, so a
     panel left near an edge stays near that edge on another resolution. */
  const onGrab = (e: ReactPointerEvent<HTMLElement>) => {
    if ((e.target as HTMLElement).closest('button')) return;

    e.preventDefault();
    const vw = window.innerWidth, vh = window.innerHeight;
    const sx = e.clientX, sy = e.clientY;
    const root = e.currentTarget.closest('.hs-root') as HTMLElement;
    const bounds = root.getBoundingClientRect();
    const gap = 16 * wsFontScale(); /* --hs-safe-gap: 16 panel units (--ws-fpx) */
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

  /* Chips for widgets the server switched off would select something that cannot be
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

  return (
    <div className="hs-root wst-root" style={{
      left: `clamp(var(--hs-safe-gap), calc(var(--ws-gutter) + ${+(pos.x * 16 / 9).toFixed(4)}vh), calc(100vw - var(--hs-panel-width) - var(--hs-safe-gap)))`,
      top: `clamp(var(--hs-safe-gap), ${pos.y}vh, calc(100vh - var(--hs-panel-height) - var(--hs-safe-gap)))`,
    }}>
      <aside className="hs-panel wst-panel">
        <div className="wst-frame" aria-hidden="true"><span className="wst-fr-t" /><span className="wst-fr-b" /><span className="wst-fr-l" /><span className="wst-fr-r" /><span className="wst-fr-tl" /><span className="wst-fr-tr" /><span className="wst-fr-bl" /><span className="wst-fr-br" /></div>

        <header className="hs-head wst-header" onPointerDown={onGrab}>
          <div className="hs-head-text">
            <h1 className="wst-title">{t(S('title'))}</h1>
            <p className="wst-sub">{t(S('sub'))}</p>
          </div>
          <button type="button" className="hs-icon hs-close wst-close" onClick={close} title={t(S('close'))}>
            <CloseIcon />
          </button>
        </header>

        <div className="hs-main">
          {/* ── the rail ──────────────────────────────────────────────────── */}
          <nav className="hs-rail">
            {panes.map((key) => {
              const Icon = I[key];
              return (
                <button key={key} type="button"
                  className={'hs-rail-btn wst-tab' + (pane === key ? ' is-on active' : '')}
                  onMouseEnter={() => play('hover')}
                  onClick={() => go(key)}>
                  <i className="hs-rail-ic"><Icon /></i>
                  <span>{t(S('pane_' + key))}</span>
                </button>
              );
            })}
          </nav>

          {/* ── the content ───────────────────────────────────────────────── */}
          <div className="hs-body">
            {pane === 'elements' && (
              <>
                <Section title={t(S('pick'))}>
                  <div className="hs-chips">
                    {GROUP_ORDER.map((group) => {
                      /* ⚠️ The server's name-and-logo block is not in this list on purpose.
                         What it says and where it sits are the admin's, and both live in
                         the Admin section -- offering a chip for it here would let a
                         player move branding they cannot change the content of. */
                      const rows = WIDGETS.filter((w) =>
                        w.group === group && !gone.has(w.id) && w.id !== 'server');
                      if (!rows.length) return null;

                      return (
                        <div className="hs-chip-group" key={group}>
                          <span className="hs-chip-cap">{t(GROUP_LABEL[group])}</span>
                          <div className="hs-chip-grid">
                            {rows.map((w) => {
                              const c = p.settings.widgets[w.id];
                              return (
                                <button key={w.id} type="button"
                                  className={'hs-chip-btn wst-card'
                                    + (p.selected === w.id ? ' is-on active' : '')
                                    + (c.show ? '' : ' is-off')}
                                  onMouseEnter={() => play('hover')}
                                  onClick={() => { play('select'); p.select(w.id); }}>
                                  <span>{name(w.id)}</span>
                                  {(!c.show || c.locked) && (
                                    <i className="hs-chip-mark">{c.show ? '⌧' : '◌'}</i>
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
                  <Section title={name(meta.id)}>
                    <div className="hs-inline">
                      <Toggle label={t(S('show'))} on={cfg.show} onChange={(v) => p.patch(meta.id, { show: v })} />
                      <Toggle label={t(S('lock'))} on={cfg.locked} onChange={(v) => p.patch(meta.id, { locked: v })} />
                    </div>

                    <div className="hs-posrow">
                      <span>{t(S('position'))} <b>{cfg.x.toFixed(1)}</b> · <b>{cfg.y.toFixed(1)}</b></span>
                      <button type="button" className="hs-linkbtn wst-button"
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
                        <span>{t(S('colour'))}</span>
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
                        <span className="hs-subcap">{t(S('rowColours'))}</span>
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
                        {meta.id === 'server' && <p className="hs-note">{t(S('logoNote'))}</p>}
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

                        <Toggle
                          label={t(S('ownLimits'))}
                          on={cfg.warn !== null || cfg.danger !== null}
                          onChange={(v) => p.patch(meta.id, v
                            ? { warn: 40, danger: 20 }
                            : { warn: null, danger: null })}
                        />
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
                ) : (
                  <p className="hs-empty">{t(S('nothing'))}</p>
                )}
              </>
            )}

            {pane === 'colours' && (
              <>
                <Section title={t(S('palettes'))}>
                  <div className="hs-presets">
                    {THEME_PRESETS.map((preset) => (
                      <button key={preset.id} type="button" className="hs-preset wst-card"
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
                      <Toggle label={t(S('dangerWins'))} on={p.settings.shape.dangerWins}
                        onChange={(v) => p.setShape({ dangerWins: v })} />
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
                <Toggle label={t(S('motion'))} on={p.settings.shape.motion}
                  onChange={(v) => p.setShape({ motion: v })} />
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
                  <Toggle label={t(S('snap'))} on={p.settings.grid.snap} onChange={(v) => p.setGrid({ snap: v })} />
                  <Slider label={t(S('snapSize'))} value={p.settings.grid.size} min={0.1} max={3} step={0.1}
                    format={(v) => `${v.toFixed(1)}%`} onChange={(v) => p.setGrid({ size: v })} />
                  <Toggle label={t(S('guides'))} on={p.settings.grid.guides} onChange={(v) => p.setGrid({ guides: v })} />
                  <p className="hs-note">{t(S('tips'))}</p>
                </Section>

                <Section title={t(S('restore'))}>
                  <div className="hs-btnrow">
                    <button type="button" className="hs-btn wst-button"
                      onClick={() => { play('select'); p.resetPositions(); }}>
                      <ResetIcon />{t(S('resetPos'))}
                    </button>
                    <button type="button" className="hs-btn wst-button is-warn danger"
                      onClick={() => { play('select'); p.resetAll(); }}>
                      <ResetIcon />{t(S('resetAll'))}
                    </button>
                  </div>
                </Section>
              </>
            )}

            {pane === 'profiles' && (
              <>
                <Section>
                  <ul className="hs-slots">
                    {Array.from({ length: PROFILE_SLOTS }, (_, i) => {
                      const slot = p.settings.profiles[i];
                      return (
                        <li className={'hs-slot wst-row' + (slot ? '' : ' is-empty')} key={i}>
                          <span className="hs-slot-name">
                            <b>{i + 1}</b>{slot ? slot.name : t(S('slotEmpty'))}
                          </span>
                          <span className="hs-slot-acts">
                            {slot && (
                              <button type="button" className="hs-linkbtn wst-button"
                                onClick={() => { play('select'); p.applyProfile(i); }}>{t(S('slotApply'))}</button>
                            )}
                            <button type="button" className="hs-linkbtn wst-button"
                              onClick={() => { play('select'); p.saveProfile(i, `${t('profile.layout')} ${i + 1}`); }}>
                              {t(S('slotSave'))}
                            </button>
                            {slot && (
                              <button type="button" className="hs-linkbtn wst-button is-warn danger"
                                onClick={() => { play('select'); p.clearProfile(i); }}>{t(S('slotClear'))}</button>
                            )}
                          </span>
                        </li>
                      );
                    })}
                  </ul>
                </Section>

                <Section title={t(S('shareOut'))}>
                  <div className="hs-coderow">
                    <input ref={shareRef} className="hs-code wst-input" readOnly value={shareCode}
                      onFocus={(e) => e.currentTarget.select()} spellCheck={false} />
                    <button type="button" className="hs-btn wst-button hs-btn-tight" onClick={copyShare}>
                      {codeNote === 'copied' ? t(S('shareCopied')) : t(S('shareCopy'))}
                    </button>
                  </div>
                </Section>

                <Section title={t(S('shareIn'))}>
                  <div className="hs-coderow">
                    <input className="hs-code wst-input" value={code} spellCheck={false}
                      onChange={(e) => { setCode(e.target.value); setCodeNote(''); }} />
                    <button type="button" className="hs-btn wst-button hs-btn-tight" disabled={code.trim() === ''}
                      onClick={applyCode}>{t(S('shareApply'))}</button>
                  </div>
                  {codeNote === 'bad' && <p className="hs-note is-bad">{t(S('shareBad'))}</p>}
                  {codeNote === 'ok' && <p className="hs-note is-good">{t(S('shareOk'))}</p>}
                </Section>
              </>
            )}
            {pane === 'admin' && p.isAdmin && (
              <>
                <p className="hs-note is-warn dangerbox">{t(S('adminOnly'))}</p>

                <Section title={t(S('srvIdentity'))}>
                  <label className="hs-urlrow">
                    <span>{t(S('srvName'))}</span>
                    <input
                      className="hs-code wst-input hs-code-text"
                      value={srvDraft.name}
                      maxLength={48}
                      spellCheck={false}
                      placeholder={t(S('srvNamePh'))}
                      onChange={(e) => editIdentity({ name: e.target.value })}
                    />
                  </label>

                  <label className="hs-urlrow">
                    <span>{t(S('srvLogo'))}</span>
                    <input
                      className="hs-code wst-input"
                      value={logoDraft}
                      spellCheck={false}
                      placeholder="https://..."
                      onChange={(e) => setLogoDraft(e.target.value)}
                      onBlur={commitLogo}
                      onKeyDown={(e) => { if (e.key === 'Enter') commitLogo(); }}
                    />
                  </label>
                  <p className={'hs-note' + (logoBad ? ' is-bad' : '')}>
                    {logoBad ? t(S('imageBad')) : t(S('srvLogoNote'))}
                  </p>
                  {srvDraft.logo.url !== '' && (
                    <button type="button" className="hs-linkbtn wst-button is-warn danger"
                      onClick={() => { play('select'); editIdentity({ logo: { ...srvDraft.logo, url: '' } }); }}>
                      {t(S('imageClear'))}
                    </button>
                  )}

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

                  {/* Placement travels with the branding: the admin drags it once and
                      every player has it there. */}
                  <Slider label={t(S('srvIdScale'))} value={srvDraft.identity.scale} min={0.4} max={3} step={0.01}
                    format={(v) => `${Math.round(v * 100)}%`}
                    onChange={(v) => editIdentity({ identity: { ...srvDraft.identity, scale: v } })} />
                  <Slider label={t(S('clarity'))} value={srvDraft.identity.opacity} min={0.15} max={1} step={0.01}
                    format={(v) => `${Math.round(v * 100)}%`}
                    onChange={(v) => editIdentity({ identity: { ...srvDraft.identity, opacity: v } })} />

                  <div className="hs-posrow">
                    <span>{t(S('position'))} <b>{srvDraft.identity.x.toFixed(1)}</b> · <b>{srvDraft.identity.y.toFixed(1)}</b></span>
                    <button type="button" className="hs-linkbtn wst-button"
                      onClick={() => { play('select'); editIdentity({ identity: { x: 98.2, y: 2, scale: 1, opacity: 1 } }); }}>
                      <ResetIcon />{t(S('restore'))}
                    </button>
                  </div>
                  <p className="hs-note">{t(S('srvIdDrag'))}</p>
                </Section>

                {/* ★ Every rate is shown as what it means, not only as what it is. Nobody
                    can tell from "1 every 90 seconds" that a character starves in two and
                    a half hours -- and that arithmetic is exactly what went unnoticed for
                    as long as it did. The consequence is printed under the sliders. */}
                <Section title={t(S('srvNeeds'))}>
                  <Slider label={t(S('srvHungerRate'))} value={srvDraft.needs.hungerRate}
                    min={0} max={25} step={0.1} format={(v) => v.toFixed(1)}
                    onChange={(v) => editNeeds({ hungerRate: v })} />
                  <Slider label={t(S('srvThirstRate'))} value={srvDraft.needs.thirstRate}
                    min={0} max={25} step={0.1} format={(v) => v.toFixed(1)}
                    onChange={(v) => editNeeds({ thirstRate: v })} />
                  <Slider label={t(S('srvInterval'))} value={srvDraft.needs.interval}
                    min={5} max={600} step={5} format={(v) => `${Math.round(v)} ${t(S('perSec'))}`}
                    onChange={(v) => editNeeds({ interval: v })} />

                  <ul className="hs-facts">
                    <li><span>{t(S('srvEmptyHunger'))}</span>
                      <b>{duration(drainMinutes(srvDraft.needs.hungerRate, srvDraft.needs.interval), t, t(S('srvNever')))}</b></li>
                    <li><span>{t(S('srvEmptyThirst'))}</span>
                      <b>{duration(drainMinutes(srvDraft.needs.thirstRate, srvDraft.needs.interval), t, t(S('srvNever')))}</b></li>
                  </ul>
                </Section>

                <Section title={t(S('srvDamage'))}>
                  <Toggle label={t(S('srvDmgOn'))} on={srvDraft.damage.enabled}
                    onChange={(v) => editDamage({ enabled: v })} />

                  {srvDraft.damage.enabled && (
                    <>
                      <Slider label={t(S('srvHungerAt'))} value={srvDraft.damage.hungerAt}
                        min={0} max={99} step={1} format={(v) => `${Math.round(v)}%`}
                        onChange={(v) => editDamage({ hungerAt: v })} />
                      <Slider label={t(S('srvThirstAt'))} value={srvDraft.damage.thirstAt}
                        min={0} max={99} step={1} format={(v) => `${Math.round(v)}%`}
                        onChange={(v) => editDamage({ thirstAt: v })} />
                      <Slider label={t(S('srvAmount'))} value={srvDraft.damage.amount}
                        min={0.5} max={25} step={0.5} format={(v) => `${v.toFixed(1)}%`}
                        onChange={(v) => editDamage({ amount: v })} />
                      <Slider label={t(S('srvDmgInterval'))} value={srvDraft.damage.interval}
                        min={3} max={300} step={1} format={(v) => `${Math.round(v)} ${t(S('perSec'))}`}
                        onChange={(v) => editDamage({ interval: v })} />
                      <Toggle label={t(S('srvCanKill'))} on={srvDraft.damage.canKill}
                        onChange={(v) => editDamage({ canKill: v })} />
                      {!srvDraft.damage.canKill && <p className="hs-note">{t(S('srvCanKillOff'))}</p>}

                      <ul className="hs-facts">
                        <li><span>{t(S('srvDeath'))}</span>
                          <b>{duration(deathMinutes(srvDraft.damage), t, t(S('srvNever')))}</b></li>
                      </ul>
                    </>
                  )}
                </Section>

                <Section title={t(S('srvFeatures'))} note={t(S('srvFeaturesNote'))}>
                  <div className="hs-featgrid">
                    {FEATURES.map((f) => (
                      <Toggle key={f.id} label={t(f.label)}
                        on={srvDraft.features[f.id] !== false}
                        onChange={(v) => editFeature(f.id, v)} />
                    ))}
                  </div>
                </Section>

                <Section>
                  <button type="button"
                    className={'hs-btn wst-button is-primary primary' + (p.srvState === 'saved' ? ' is-done' : '')}
                    disabled={p.srvState === 'saving'}
                    onClick={() => { play('select'); p.publishServer(); }}>
                    {p.srvState === 'saved' ? t(S('srvSaved'))
                      : p.srvState === 'saving' ? t(S('saving'))
                        : p.srvState === 'dirty' ? t(S('srvSending')) : t(S('srvSave'))}
                  </button>
                  <p className="hs-note">{t(S('srvLiveNote'))}</p>
                </Section>
              </>
            )}
          </div>
        </div>

        <footer className="hs-foot">
          <button type="button"
            className={'hs-btn wst-button is-primary primary' + (p.saving === 'saved' ? ' is-done' : '')}
            disabled={p.saving === 'saving'}
            onClick={() => { play('select'); p.onSave(); }}>
            {saveLabel}
          </button>
          <button type="button" className="hs-btn wst-button" onClick={close}>{t(S('close'))}</button>
        </footer>
      </aside>
    </div>
  );
}
