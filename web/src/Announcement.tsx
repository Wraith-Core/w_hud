/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · Announcement.tsx                                                 2.1.0
 * The server's announcement: white text at the top centre, directly under the compass (and the
 * place name, when that sits under it), in the look of the game's own shard -- a title, the
 * game's divider, the message -- with no plate behind it.
 *
 *   { action: 'announce', id, title?, text, seconds }   show (replaces the one on screen)
 *   { action: 'announce:clear' }                         fade the one on screen out now
 *
 * ★ Drawn here and not by a feed native: the RDR2 text engine has no Arabic glyphs, so the
 *   game's own shard would print an Arabic announcement as empty boxes. This frame has the
 *   theme's Arabic faces.
 *
 * ★ Placed from the compass widget's drawn box (data-hw="compass" / "location"), so it stays
 *   under the compass wherever the player moved it. A compass that is off, or moved far from
 *   the top, leaves the shard at the top centre where the compass would be.
 *
 * ★ Outside .hud-root (App.tsx): an announcement still shows while the HUD is hidden.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useRef, useState } from 'react';
import { useI18n } from './i18n';
import './announcement.css';

interface Shown { id: number; title: string | null; text: string; seconds: number }

const FADE_MS = 450;
const MAX_TEXT = 300;
const MAX_TITLE = 60;
const MAX_SECONDS = 1800;
/* the gap under the compass, in vh */
const GAP_VH = 1.2;
/* where it sits when there is no compass to hang from: under the compass's home spot */
const HOME = { x: 50, y: 9 };

/** The point (in vw / vh) the shard's top centre goes to. */
function anchorOf(): { x: number; y: number } {
  const vw = window.innerWidth || 1, vh = window.innerHeight || 1;
  let bottom = -1, centre = -1;
  for (const id of ['compass', 'location']) {
    const node = document.querySelector<HTMLElement>(`[data-hw="${id}"]`);
    if (!node || node.dataset.hwHidden === '1') continue;
    const r = node.getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) continue;
    /* only a widget that is still near the top centre: one dragged to a corner is not "the compass above" */
    if (r.top > vh * 0.3 || Math.abs(r.left + r.width / 2 - vw / 2) > vw * 0.25) continue;
    if (r.bottom > bottom) bottom = r.bottom;
    if (id === 'compass' || centre < 0) centre = r.left + r.width / 2;
  }
  if (bottom < 0) return HOME;
  return { x: (centre / vw) * 100, y: (bottom / vh) * 100 + GAP_VH };
}

const str = (v: unknown, max: number): string | null => {
  if (typeof v !== 'string') return null;
  const s = v.trim();
  return s === '' ? null : Array.from(s).slice(0, max).join('');
};

export default function Announcement() {
  const { t } = useI18n();
  const [shown, setShown] = useState<Shown | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [pos, setPos] = useState(HOME);
  const timers = useRef<number[]>([]);

  useEffect(() => {
    const stop = () => { timers.current.forEach((h) => window.clearTimeout(h)); timers.current = []; };
    const leave = () => {
      stop();
      setLeaving(true);
      timers.current.push(window.setTimeout(() => { setShown(null); setLeaving(false); }, FADE_MS));
    };
    const onMsg = (e: MessageEvent) => {
      const d = (e.data || {}) as Record<string, unknown>;
      if (d.action === 'announce:clear') { leave(); return; }
      if (d.action !== 'announce') return;
      const text = str(d.text, MAX_TEXT);
      if (!text) return;
      const n = Number(d.seconds);
      const seconds = Number.isFinite(n) ? Math.min(Math.max(n, 1), MAX_SECONDS) : 10;
      stop();
      setLeaving(false);
      setPos(anchorOf());
      setShown({ id: Number(d.id) || Date.now(), title: str(d.title, MAX_TITLE), text, seconds });
      /* the fade is inside the time asked for: it is gone at exactly `seconds` */
      timers.current.push(window.setTimeout(leave, Math.max(seconds * 1000 - FADE_MS, 0)));
    };
    window.addEventListener('message', onMsg);
    return () => { window.removeEventListener('message', onMsg); stop(); };
  }, []);

  /* follow the compass while it is up: the player may open the HUD editor and move it */
  useEffect(() => {
    if (!shown) return undefined;
    const id = window.setInterval(() => setPos(anchorOf()), 1000);
    return () => window.clearInterval(id);
  }, [shown]);

  if (!shown) return null;
  return (
    <div
      key={shown.id}
      className={'ann' + (leaving ? ' is-leaving' : '')}
      style={{ left: `${pos.x}vw`, top: `${pos.y}vh` }}
      role="status"
      aria-live="polite"
    >
      <div className="ann-title" dir="auto">{shown.title ?? t('announce.title')}</div>
      <div className="ann-rule" aria-hidden="true" />
      <div className="ann-text" dir="auto">{shown.text}</div>
    </div>
  );
}
