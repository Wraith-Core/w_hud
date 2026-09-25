/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/ColorField.tsx
 * A colour picker with no dependency -- a swatch that opens a shelf of the theme's tones.
 *
 * ★ Why not <input type="color">?
 *
 *   Because CEF opens the operating system's colour dialog for it -- a Windows window,
 *   outside the game, behind it in fullscreen. The player clicks the swatch and nothing
 *   appears to happen. So the picker is drawn here, in the page, in the HUD's own idiom.
 *
 * ★ Why a shelf and no colour wheel?
 *
 *   The HUD is white and black, like Red Dead's own: the only colours it may draw are the
 *   theme's ink and paper tones and, for danger alone, its one red (palette.ts). A hue rail
 *   would offer colours the HUD then refuses to paint. So the choice is the tones themselves,
 *   lightest first, and the red only on the field that means danger.
 *
 * ⚠️ `value` may still be a colour saved by an older build (a blue accent, a green circle).
 *   It is shown as the tone it is drawn in -- the save itself is not changed until the
 *   player picks something.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { readableInk } from './color';
import { RED, TONES, toTone } from './palette';

interface Props {
  value: string;
  onChange: (hex: string) => void;
  /** Shown as a "follow the theme" choice when the widget has no colour of its own. */
  inherit?: { active: boolean; label: string; onPick: () => void };
  title?: string;
  /** The danger field: the theme's red is offered too (and a reddish save is drawn red). */
  red?: boolean;
}

export function ColorField({ value, onChange, inherit, title, red = false }: Props) {
  const [open, setOpen] = useState(false);
  /* ⚠️ The popover is placed in viewport coordinates, not relative to the swatch.
     The panel scrolls its body and clips its own overflow, so a popover positioned inside
     it is cut off by whichever edge it reaches first -- and the picker is exactly the thing
     that needs to be taller than the row it hangs from. Fixed coordinates measured off the
     swatch escape both, and the clamp keeps it on screen. */
  const [at, setAt] = useState({ left: 0, top: 0 });
  const box = useRef<HTMLDivElement>(null);
  const btn = useRef<HTMLButtonElement>(null);
  const pop = useRef<HTMLDivElement>(null);

  const shown = toTone(value, { red });
  const shelf: string[] = red ? [RED, ...TONES] : [...TONES];

  /* Clicking anywhere else puts the picker away -- including on another swatch, so two
     pickers are never open over one another. */
  useEffect(() => {
    if (!open) return;

    const onDown = (e: MouseEvent) => {
      const target = e.target as Node;
      /* ⚠️ Both refs, not just the swatch's: the popover is portalled out of this
         component's DOM (see below), so it is not inside `box` any more -- and checking
         `box` alone closed the picker on the first click *inside* it. */
      if (box.current?.contains(target)) return;
      if (pop.current?.contains(target)) return;
      setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); setOpen(false); } };

    window.addEventListener('mousedown', onDown, true);
    window.addEventListener('keydown', onKey, true);

    return () => {
      window.removeEventListener('mousedown', onDown, true);
      window.removeEventListener('keydown', onKey, true);
    };
  }, [open]);

  /* Measure the actual editor-scale popup, independently from the HUD's tiny rem. */
  const place = () => {
    const el = btn.current;
    if (!el) return;

    const r = el.getBoundingClientRect();
    const unit = Math.max(1, Math.min(2, window.innerHeight / 1080));
    const bounds = pop.current?.getBoundingClientRect();
    const w = bounds?.width ?? 288 * unit;
    const h = bounds?.height ?? 160 * unit;
    const gap = 16 * unit;

    /* Below the swatch when there is room for it, above when there is not, and never
       past either side -- so a swatch near the bottom of the panel still opens fully. */
    const top = r.bottom + gap + h > window.innerHeight ? r.top - gap - h : r.bottom + gap;

    setAt({
      left: Math.max(gap, Math.min(window.innerWidth - w - gap, r.right - w)),
      top: Math.max(gap, Math.min(window.innerHeight - h - gap, top)),
    });
  };

  useLayoutEffect(() => {
    if (!open) return;
    place();
    const observer = new ResizeObserver(place);
    if (pop.current) observer.observe(pop.current);
    window.addEventListener('resize', place);
    window.addEventListener('scroll', place, true);
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', place);
      window.removeEventListener('scroll', place, true);
    };
  }, [open]);

  const toggle = () => {
    if (!open) place();
    setOpen((v) => !v);
  };

  return (
    <div className="hs-color" ref={box}>
      <button
        ref={btn}
        type="button"
        className={'hs-swatch' + (open ? ' is-open' : '')}
        style={{ background: shown, color: readableInk(shown) }}
        onClick={toggle}
        title={title}
      >
        <span>{inherit?.active ? inherit.label : shown}</span>
      </button>

      {/* ★ Portalled to <body>, not left where it was written.
          The panel's entrance animation ends on a transform, and `animation-fill-mode:
          both` leaves that transform in place for good -- which makes .hs-root the
          containing block for every fixed-position descendant and hands .hs-panel's
          `overflow: hidden` something to clip. So the popover was measured against the
          viewport and then positioned against the panel, and cut off by it besides.
          Out here it is a child of <body>: viewport coordinates mean the viewport, and
          nothing above it clips. */}
      {open && createPortal((
        <div
          ref={pop}
          className="hs-picker wst-root wst-panel"
          style={{ left: `${at.left}px`, top: `${at.top}px` }}
          dir={document.documentElement.dir === 'rtl' ? 'rtl' : 'ltr'}
        >
          <span className="wst-frame" aria-hidden="true"><span className="wst-fr-t" /><span className="wst-fr-b" /><span className="wst-fr-l" /><span className="wst-fr-r" /><span className="wst-fr-tl" /><span className="wst-fr-tr" /><span className="wst-fr-bl" /><span className="wst-fr-br" /></span>

          <div className={'hs-shelf' + (red ? ' has-red' : '')}>
            {shelf.map((hex) => (
              <button
                key={hex}
                type="button"
                className={'hs-chip' + (hex === RED ? ' is-red' : '') + (hex === shown && !inherit?.active ? ' is-on' : '')}
                style={{ background: hex, color: readableInk(hex) }}
                onClick={() => { onChange(hex); setOpen(false); }}
                title={hex}
              />
            ))}
          </div>

          {inherit && (
            <div className="hs-hexrow">
              <button
                type="button"
                className={'hs-mini' + (inherit.active ? ' is-on' : '')}
                onClick={() => { inherit.onPick(); setOpen(false); }}
              >
                {inherit.label}
              </button>
            </div>
          )}
        </div>
      ), document.body)}
    </div>
  );
}
