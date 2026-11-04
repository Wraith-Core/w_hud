/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/layout.tsx
 * The free layout: one wrapper that gives any HUD element a position of its own.
 *
 * ═══ How a widget is placed ═══
 *
 *   left/top put the element's box at the anchor, and the transform pulls it back by
 *   the widget's own origin -- so a right-anchored column keeps its right edge as the
 *   numbers inside it grow, and a core stays centred on its point:
 *
 *       left: x%;  top: y%;
 *       transform-origin: <ox>% <oy>%;
 *       transform: translate(-<ox>%, -<oy>%) scale(s);
 *
 *   ★ The transform-origin matters as much as the translate: without it the widget
 *     would scale about its own centre and creep away from the point the player
 *     dropped it on. With it, scaling happens **about the anchor** -- so a widget
 *     enlarged after being placed stays exactly where it was put.
 *
 * ═══ Dragging ═══
 *
 *   Pointer events with capture, so a fast drag that outruns the cursor does not lose
 *   the element. Two kinds of snapping, in this order:
 *
 *     1. alignment with the other widgets (their edges and centres) -- the guides
 *     2. the grid, only where no alignment was found
 *
 *   ★ Alignment beats the grid deliberately. A grid that overrides alignment is a grid
 *     that stops you lining two circles up unless the gap between them happens to be a
 *     whole number of steps -- which is the one thing a player laying out a HUD is
 *     actually trying to do. Holding Shift suspends both for free placement.
 * ════════════════════════════════════════════════════════════════════════════ */

import {
  createContext, useCallback, useContext, useEffect, useRef, useState,
  type CSSProperties, type PointerEvent as ReactPointerEvent, type ReactNode,
} from 'react';
import { WIDGET_BY_ID, type HudSettings, type WidgetCfg, type WidgetId } from './types';
import { useI18n } from '../i18n';
import { pxToX, xToCss, xToPx, xUnitsVh } from './frame';
import { wsScale } from '../wsScale';

/* ── how close two edges must be, in design pixels (1080p), before they snap together ── */
const SNAP_PX = 7;

export interface Guides { x: number | null; y: number | null }

interface LayoutValue {
  settings: HudSettings;
  editing: boolean;
  selected: WidgetId | null;
  /**
   * Widgets the server has switched off.
   *
   * ★ Gone entirely, editor included. A feature the admin turned off is not a thing the
   *   player is choosing to hide -- offering it in the editor would let them arrange a
   *   HUD around a circle that is never going to appear.
   */
  disabled: Set<WidgetId>;
  select: (id: WidgetId | null) => void;
  patch: (id: WidgetId, p: Partial<WidgetCfg>) => void;
}

const Ctx = createContext<LayoutValue | null>(null);

export const HudLayoutProvider = ({ value, children }: { value: LayoutValue; children: ReactNode }) => (
  <Ctx.Provider value={value}>{children}</Ctx.Provider>
);

export function useHudLayout(): LayoutValue {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useHudLayout outside its provider');
  return ctx;
}

/* ════════════════════════════════════════════════════════════════════════════
 * Snapping
 * ════════════════════════════════════════════════════════════════════════════ */

interface Edges { v: number[]; h: number[] }

/**
 * Every line the dragged widget may line up against: the other widgets' left/centre/right
 * and top/middle/bottom, plus the screen's own edges and centre.
 *
 * ⚠️ Read from the DOM rather than from the settings: a widget's *anchor* is in the
 * settings but its **edges** depend on how wide the content rendered -- and lining up
 * two circles means lining up what is drawn, not the invisible points they hang from.
 */
function collectEdges(exclude: WidgetId): Edges {
  const vw = window.innerWidth, vh = window.innerHeight;
  const v: number[] = [0, vw / 2, vw];
  const h: number[] = [0, vh / 2, vh];

  const nodes = document.querySelectorAll<HTMLElement>('[data-hw]');

  nodes.forEach((node) => {
    if (node.dataset.hw === exclude) return;
    if (node.dataset.hwHidden === '1') return;

    const r = node.getBoundingClientRect();
    if (r.width <= 0 && r.height <= 0) return;

    v.push(r.left, r.left + r.width / 2, r.right);
    h.push(r.top, r.top + r.height / 2, r.bottom);
  });

  return { v, h };
}

/** The nearest line within SNAP_PX of any of the three probes, or null. */
function nearest(probes: number[], lines: number[]): { delta: number; line: number } | null {
  let best: { delta: number; line: number } | null = null;

  for (const probe of probes) {
    for (const line of lines) {
      const delta = line - probe;
      if (Math.abs(delta) > SNAP_PX * wsScale()) continue;
      if (!best || Math.abs(delta) < Math.abs(best.delta)) best = { delta, line };
    }
  }

  return best;
}

/* ════════════════════════════════════════════════════════════════════════════
 * The wrapper
 * ════════════════════════════════════════════════════════════════════════════ */

interface WidgetProps {
  id: WidgetId;
  children: ReactNode;
  /** Extra classes for the wrapper -- content alignment, mostly. */
  className?: string;
  /**
   * Placement that lives somewhere other than this player's settings.
   *
   * ★ The server's name-and-logo block is the one of these: its position belongs to the
   *   admin and reaches everybody, so it cannot be read from -- or written to -- the
   *   per-player record like every other widget. `onPatch` absent means read-only:
   *   the block is drawn where the admin put it and nobody else can move it.
   */
  override?: { cfg: WidgetCfg; onPatch?: (p: Partial<WidgetCfg>) => void; tag?: string };
}

export function HudWidget({ id, children, className, override }: WidgetProps) {
  const { settings, editing, selected, select, patch, disabled } = useHudLayout();
  const { t } = useI18n();
  const meta = WIDGET_BY_ID[id];
  const cfg = override ? override.cfg : settings.widgets[id];

  const ref = useRef<HTMLDivElement>(null);
  const [guides, setGuides] = useState<Guides>({ x: null, y: null });
  const [dragging, setDragging] = useState(false);

  /* A widget switched off is gone from the HUD -- but it stays in the editor, faint and
     marked, because a thing you cannot see is a thing you cannot switch back on in place. */
  const hidden = !cfg.show;
  if (disabled.has(id)) return null;
  if (hidden && !editing) return null;

  const [ox, oy] = meta.origin;
  const scale = cfg.scale * settings.scale;

  const style: CSSProperties = {
    /* x is a share of the 16:9 frame, anchored to the nearest edge (frame.ts) */
    left: xToCss(cfg.x),
    top: `${cfg.y}%`,
    transformOrigin: `${ox * 100}% ${oy * 100}%`,
    transform: `translate(${-ox * 100}%, ${-oy * 100}%) scale(${scale})`,
    opacity: hidden ? undefined : cfg.opacity,
  };

  /* Painted exactly as chosen (an older save's colour was read as the tone it showed: types.ts). */
  if (cfg.color) (style as Record<string, string>)['--w-color'] = cfg.color;

  const onPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!editing) return;

    e.preventDefault();
    e.stopPropagation();

    /* An overridden widget is not part of the player's element list, so selecting it
       would fill the inspector with values that are not the ones being edited. */
    if (!override) select(id);

    if (cfg.locked) return;
    if (override && !override.onPatch) return;

    const el = ref.current;
    if (!el) return;

    const vw = window.innerWidth, vh = window.innerHeight;
    const rect = el.getBoundingClientRect();

    /* The gap between the anchor and the drawn box. Constant for the whole drag (nothing
       resizes mid-drag), so the widget's future rect is a single addition away. */
    const anchorX = xToPx(cfg.x, vw, vh);
    const anchorY = (cfg.y / 100) * vh;
    const offX = rect.left - anchorX;
    const offY = rect.top - anchorY;
    const { width, height } = rect;

    const startX = e.clientX, startY = e.clientY;
    const edges = collectEdges(id);
    const step = settings.grid.size;

    el.setPointerCapture(e.pointerId);
    setDragging(true);

    const move = (ev: PointerEvent) => {
      const free = ev.shiftKey;   /* Shift = place it exactly where the cursor is */

      let px = anchorX + (ev.clientX - startX);
      let py = anchorY + (ev.clientY - startY);
      let guideX: number | null = null;
      let guideY: number | null = null;

      if (!free && settings.grid.guides) {
        const left = px + offX;
        const top = py + offY;

        const hit = nearest([left, left + width / 2, left + width], edges.v);
        if (hit) { px += hit.delta; guideX = hit.line; }

        const vhit = nearest([top, top + height / 2, top + height], edges.h);
        if (vhit) { py += vhit.delta; guideY = vhit.line; }
      }

      let nx = pxToX(px, vw, vh);
      let ny = (py / vh) * 100;

      if (!free && settings.grid.snap) {
        if (guideX === null) nx = Math.round(nx / step) * step;
        if (guideY === null) ny = Math.round(ny / step) * step;
      }

      /* ★ Clamped so nothing can be dropped where it cannot be picked up again.
         -10..110 rather than 0..100: an anchor may sit just off-screen while the body
         it carries is fully visible -- a right-anchored column is exactly that. */
      nx = Math.max(-10, Math.min(110, nx));
      ny = Math.max(-10, Math.min(110, ny));

      setGuides({ x: guideX, y: guideY });

      const moved = { x: Math.round(nx * 100) / 100, y: Math.round(ny * 100) / 100 };
      if (override?.onPatch) override.onPatch(moved); else patch(id, moved);
    };

    const up = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
      window.removeEventListener('pointercancel', up);
      setGuides({ x: null, y: null });
      setDragging(false);
    };

    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
    window.addEventListener('pointercancel', up);
  };

  const label = override?.tag ?? t(meta.label);

  return (
    <>
      <div
        ref={ref}
        data-hw={id}
        data-hw-hidden={hidden ? '1' : undefined}
        className={
          'hw'
          + (className ? ' ' + className : '')
          + (editing ? ' hw-edit' : '')
          + (selected === id && editing && !override ? ' is-sel' : '')
          + (dragging ? ' is-drag' : '')
          + (cfg.locked ? ' is-locked' : '')
          + (hidden ? ' is-off' : '')
          + (override && !override.onPatch ? ' hw-fixed' : '')
          /* ★ The name tag hangs above its widget, which puts it off the top of the
             screen for anything near it -- the compass, the server name, the ammo.
             Below that line it hangs underneath instead. */
          + (cfg.y < 14 ? ' hw-high' : '')
        }
        style={style}
        onPointerDown={editing && (!override || override.onPatch) ? onPointerDown : undefined}
      >
        {children}

        {editing && (!override || override.onPatch) && (
          <span className="hw-tag" aria-hidden="true">
            {cfg.locked && <b className="hw-tag-ic">⌧</b>}
            {hidden && <b className="hw-tag-ic">◌</b>}
            {label}
          </span>
        )}
      </div>

      {dragging && (guides.x !== null || guides.y !== null) && (
        <div className="hw-guides" aria-hidden="true">
          {guides.x !== null && <i className="hw-guide-v" style={{ left: `${guides.x}px` }} />}
          {guides.y !== null && <i className="hw-guide-h" style={{ top: `${guides.y}px` }} />}
        </div>
      )}
    </>
  );
}

/* ════════════════════════════════════════════════════════════════════════════
 * Nudging with the arrow keys
 *
 * ★ A mouse cannot place a thing at 43.20 when the pixel next to it is 43.27. Every
 *   editor that is taken seriously answers that with the arrow keys, and so does this
 *   one: a tap is a tenth of a percent, Shift is a whole one.
 * ════════════════════════════════════════════════════════════════════════════ */
export function useNudge(
  editing: boolean,
  selected: WidgetId | null,
  settings: HudSettings,
  patch: (id: WidgetId, p: Partial<WidgetCfg>) => void,
): void {
  const patchRef = useRef(patch);
  patchRef.current = patch;

  const settingsRef = useRef(settings);
  settingsRef.current = settings;

  useEffect(() => {
    if (!editing || !selected) return;

    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      /* Never while a field has the caret -- the arrows belong to the field then. */
      if (target && /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName)) return;

      let dx = 0, dy = 0;
      if (e.key === 'ArrowLeft') dx = -1;
      else if (e.key === 'ArrowRight') dx = 1;
      else if (e.key === 'ArrowUp') dy = -1;
      else if (e.key === 'ArrowDown') dy = 1;
      else return;

      e.preventDefault();

      const cfg = settingsRef.current.widgets[selected];
      if (!cfg || cfg.locked) return;

      const step = e.shiftKey ? 1 : 0.1;
      patchRef.current(selected, {
        x: Math.round((cfg.x + dx * step) * 100) / 100,
        y: Math.round((cfg.y + dy * step) * 100) / 100,
      });
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [editing, selected]);
}

/** The faint grid drawn behind everything while the layout is being edited. */
export const EditGrid = ({ step }: { step: number }) => (
  <div
    className="hw-grid"
    aria-hidden="true"
    style={{ backgroundSize: `${xUnitsVh(step)}vh ${xUnitsVh(step)}vh` }}
  />
);
