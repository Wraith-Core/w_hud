/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/ColorField.tsx
 * A colour picker with no dependency -- a swatch that opens a saturation square,
 * a hue rail, a hex field and a shelf of ready colours.
 *
 * ★ Why not <input type="color">?
 *
 *   Because CEF opens the operating system's colour dialog for it -- a Windows window,
 *   outside the game, behind it in fullscreen. The player clicks the swatch and nothing
 *   appears to happen. So the picker is drawn here, in the page, in the HUD's own idiom.
 *
 * ⚠️ Hue is kept in a ref alongside the hex, not derived from it on every render: a grey
 *   has no hue (s = 0), so dragging the saturation square down to grey and back up again
 *   would throw the hue away and come back red. The rail owns the hue; the square owns
 *   saturation and value.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';
import { createPortal } from 'react-dom';
import { hexToHsv, hsvToHex, normHex, readableInk } from './color';

/* A shelf of colours that read well over a dark, moving background -- nothing muddy,
   nothing so dark it disappears against the game. */
const SHELF = [
  '#FFFFFF', '#E7CE8A', '#C8A44D', '#E8C547', '#F2994A', '#E05555',
  '#CB0101', '#B48CD9', '#8EC8E8', '#5AB054', '#8FA97B', '#8C8C8C',
];

interface Props {
  value: string;
  onChange: (hex: string) => void;
  /** Shown as a "follow the theme" choice when the widget has no colour of its own. */
  inherit?: { active: boolean; label: string; onPick: () => void };
  title?: string;
}

export function ColorField({ value, onChange, inherit, title }: Props) {
  const [open, setOpen] = useState(false);
  const [text, setText] = useState(value);
  /* ⚠️ The popover is placed in viewport coordinates, not relative to the swatch.
     The panel scrolls its body and clips its own overflow, so a popover positioned inside
     it is cut off by whichever edge it reaches first -- and the colour picker is exactly
     the thing that needs to be taller than the row it hangs from. Fixed coordinates
     measured off the swatch escape both, and the clamp keeps it on screen. */
  const [at, setAt] = useState({ left: 0, top: 0 });
  const box = useRef<HTMLDivElement>(null);
  const btn = useRef<HTMLButtonElement>(null);
  const pop = useRef<HTMLDivElement>(null);

  const hsv = hexToHsv(value);
  const hueRef = useRef(hsv.h);
  if (hsv.s > 0.02 && hsv.v > 0.02) hueRef.current = hsv.h;
  const hue = hueRef.current;

  useEffect(() => { setText(value); }, [value]);

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

  /** One handler for both surfaces: a press reads immediately, then follows the pointer. */
  const track = (
    e: ReactPointerEvent<HTMLDivElement>,
    read: (fx: number, fy: number) => void,
  ) => {
    e.preventDefault();
    e.stopPropagation();

    const el = e.currentTarget;
    const rect = el.getBoundingClientRect();

    const send = (cx: number, cy: number) => {
      read(
        Math.min(1, Math.max(0, (cx - rect.left) / rect.width)),
        Math.min(1, Math.max(0, (cy - rect.top) / rect.height)),
      );
    };

    send(e.clientX, e.clientY);

    const move = (ev: PointerEvent) => send(ev.clientX, ev.clientY);
    const up = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
    };

    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
  };

  const commitText = () => {
    const hex = normHex(text, value);
    setText(hex);
    onChange(hex);
  };

  /* The popover's own size in pixels -- both are rem, and 1rem is 0.64vh here. */
  const place = () => {
    const el = btn.current;
    if (!el) return;

    const r = el.getBoundingClientRect();
    const rem = window.innerHeight * 0.0064;
    const w = 26 * rem;
    const h = 25 * rem;
    const gap = 0.6 * rem;

    /* Below the swatch when there is room for it, above when there is not, and never
       past either side -- so a swatch near the bottom of the panel still opens fully. */
    const top = r.bottom + gap + h > window.innerHeight ? r.top - gap - h : r.bottom + gap;

    setAt({
      left: Math.max(gap, Math.min(window.innerWidth - w - gap, r.right - w)),
      top: Math.max(gap, top),
    });
  };

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
        style={{ background: value, color: readableInk(value) }}
        onClick={toggle}
        title={title}
      >
        <span>{inherit?.active ? inherit.label : value}</span>
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
          className="hs-picker"
          style={{ left: `${at.left}px`, top: `${at.top}px` }}
          dir={document.documentElement.dir === 'rtl' ? 'rtl' : 'ltr'}
        >
          <div
            className="hs-sv"
            style={{ background: `linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, ${hsvToHex({ h: hue, s: 1, v: 1 })})` }}
            onPointerDown={(e) => track(e, (fx, fy) => onChange(hsvToHex({ h: hue, s: fx, v: 1 - fy })))}
          >
            <i
              className="hs-sv-dot"
              style={{ left: `${hsv.s * 100}%`, top: `${(1 - hsv.v) * 100}%`, borderColor: readableInk(value) }}
            />
          </div>

          <div
            className="hs-hue"
            onPointerDown={(e) => track(e, (fx) => {
              hueRef.current = fx * 360;
              onChange(hsvToHex({ h: fx * 360, s: Math.max(hsv.s, 0.05), v: Math.max(hsv.v, 0.15) }));
            })}
          >
            <i className="hs-hue-dot" style={{ left: `${(hue / 360) * 100}%` }} />
          </div>

          <div className="hs-shelf">
            {SHELF.map((hex) => (
              <button
                key={hex}
                type="button"
                className={'hs-chip' + (hex === value ? ' is-on' : '')}
                style={{ background: hex }}
                onClick={() => onChange(hex)}
                title={hex}
              />
            ))}
          </div>

          <div className="hs-hexrow">
            <input
              className="hs-hex"
              value={text}
              spellCheck={false}
              maxLength={7}
              onChange={(e) => setText(e.target.value)}
              onBlur={commitText}
              onKeyDown={(e) => { if (e.key === 'Enter') commitText(); }}
            />
            {inherit && (
              <button
                type="button"
                className={'hs-mini' + (inherit.active ? ' is-on' : '')}
                onClick={() => { inherit.onPick(); setOpen(false); }}
              >
                {inherit.label}
              </button>
            )}
          </div>
        </div>
      ), document.body)}
    </div>
  );
}
