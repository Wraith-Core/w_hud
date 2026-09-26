/* ════════════════════════════════════════════════════════════════════════════
 * w_hud · settings/ColorField.tsx
 * A colour picker with no dependency -- a swatch that opens a shelf of the theme's tones,
 * and on the two free fields a full chooser beside them.
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
 *
 * ★ Except on a free field (`free`: the warning and the money colour). The owner wants those
 *   in any hue, and the HUD paints them exactly as chosen (theme.ts), so the picker offers
 *   everything: the same tones on top as quick picks, then a saturation square and a hue rail,
 *   a row of ready colours, and a #hex field -- and the swatch shows the colour itself, not a
 *   tone. The picker stays open while a free colour is picked, so it can be nudged afterwards.
 *
 * ⚠️ Hue is kept in a ref alongside the hex, not derived from it on every render: a grey
 *   has no hue (s = 0), so dragging the saturation square down to grey and back up again
 *   would throw the hue away and come back red. The rail owns the hue; the square owns
 *   saturation and value.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useLayoutEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';
import { createPortal } from 'react-dom';
import { useI18n } from '../i18n';
import { hexToHsv, hsvToHex, normHex, readableInk } from './color';
import { PAPER, RED, TONES, toTone } from './palette';

/* Ready colours for a free field: ones that read over a dark, moving game -- a warning yellow
   and orange, a red, two golds for the money, a green, a blue, a violet. Nothing so dark that it
   disappears against the ground. (The earlier build's shelf, less its whites and greys, which
   the tones above them already cover.) */
const READY = ['#E8C547', '#F2994A', '#E05555', '#E7CE8A', '#C8A44D', '#5AB054', '#8EC8E8', '#B48CD9'];

/** #RRGGBB (the # optional) -- applied as it is typed; anything shorter waits for Enter. */
const FULL_HEX = /^#?[0-9a-f]{6}$/i;

interface Props {
  value: string;
  onChange: (hex: string) => void;
  /** Shown as a "follow the theme" choice when the widget has no colour of its own. */
  inherit?: { active: boolean; label: string; onPick: () => void };
  title?: string;
  /** The danger field: the theme's red is offered too (and a reddish save is drawn red). */
  red?: boolean;
  /** Any colour (the warning, the money): the full chooser, shown and painted exactly as chosen. */
  free?: boolean;
}

export function ColorField({ value, onChange, inherit, title, red = false, free = false }: Props) {
  const { t } = useI18n();
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

  /* A free field shows (and is painted in) the colour itself; every other field, its tone. */
  const exact = normHex(value, PAPER);
  const shown = free ? exact : toTone(value, { red });
  const shelf: string[] = red ? [RED, ...TONES] : [...TONES];

  const hsv = hexToHsv(exact);
  const hueRef = useRef(hsv.h);
  if (hsv.s > 0.02 && hsv.v > 0.02) hueRef.current = hsv.h;
  const hue = hueRef.current;

  const [text, setText] = useState(exact);
  useEffect(() => { setText(exact); }, [exact]);

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

  /* The hue rail on a grey (or near-black) colour: a grey has no hue to move, so picking one
     lifts it to a colour you can actually see rather than a grey with a tint nobody notices. */
  const pickHue = (h: number) => {
    hueRef.current = h;
    onChange(hsvToHex({ h, s: hsv.s < 0.15 ? 0.8 : hsv.s, v: hsv.v < 0.3 ? 0.9 : hsv.v }));
  };

  /* Enter always applies what is in the field (even the colour already shown, which is how a
     "none chosen" money field is given that colour on purpose); leaving the field applies it
     only if it was changed, so clicking through it never picks a colour by accident. */
  const commitText = (force: boolean) => {
    const hex = normHex(text, exact);
    setText(hex);
    if (force || hex !== exact) onChange(hex);
  };

  /* A chip: a tone field closes on the pick (there is nothing else to do there); a free one
     stays open so the colour can still be nudged on the square or the rail. */
  const pickChip = (hex: string) => {
    onChange(hex);
    if (!free) setOpen(false);
  };

  /* Measure the actual editor-scale popup, independently from the HUD's tiny rem. */
  const place = () => {
    const el = btn.current;
    if (!el) return;

    const r = el.getBoundingClientRect();
    const unit = Math.max(1, Math.min(2, window.innerHeight / 1080));
    const bounds = pop.current?.getBoundingClientRect();
    const w = bounds?.width ?? 288 * unit;
    const h = bounds?.height ?? (free ? 440 : 160) * unit;
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
        {inherit?.active ? <span>{inherit.label}</span> : <span dir="ltr">{shown}</span>}
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
          className={'hs-picker wst-root wst-panel' + (free ? ' is-free' : '')}
          style={{ left: `${at.left}px`, top: `${at.top}px` }}
          dir={document.documentElement.dir === 'rtl' ? 'rtl' : 'ltr'}
        >
          <span className="wst-frame" aria-hidden="true"><span className="wst-fr-t" /><span className="wst-fr-b" /><span className="wst-fr-l" /><span className="wst-fr-r" /><span className="wst-fr-tl" /><span className="wst-fr-tr" /><span className="wst-fr-bl" /><span className="wst-fr-br" /></span>

          {free && <span className="hs-pick-cap">{t('settings.pickTones')}</span>}
          <div className={'hs-shelf' + (red ? ' has-red' : '')}>
            {shelf.map((hex) => (
              <button
                key={hex}
                type="button"
                className={'hs-chip' + (hex === RED ? ' is-red' : '') + (hex === shown && !inherit?.active ? ' is-on' : '')}
                style={{ background: hex, color: readableInk(hex) }}
                onClick={() => pickChip(hex)}
                title={hex}
              />
            ))}
          </div>

          {/* ── the free chooser: square, rail, ready colours (the warning and the money only) ── */}
          {free && (
            <>
              <span className="hs-pick-cap">{t('settings.pickAny')}</span>
              {/* ⚠️ Physical left/right on purpose, in both directions: the gradients run left to
                  right and the pointer is read against the box's left edge, so under dir=rtl the
                  square and the rail must not be mirrored or the dot would land opposite the colour. */}
              <div
                className="hs-sv"
                style={{ background: `linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, ${hsvToHex({ h: hue, s: 1, v: 1 })})` }}
                onPointerDown={(e) => track(e, (fx, fy) => onChange(hsvToHex({ h: hue, s: fx, v: 1 - fy })))}
              >
                <i
                  className="hs-sv-dot"
                  style={{ left: `${hsv.s * 100}%`, top: `${(1 - hsv.v) * 100}%`, borderColor: readableInk(exact) }}
                />
              </div>

              <div className="hs-hue" onPointerDown={(e) => track(e, (fx) => pickHue(fx * 360))}>
                <i className="hs-hue-dot" style={{ left: `${(hue / 360) * 100}%` }} />
              </div>

              <div className="hs-shelf is-ready">
                {READY.map((hex) => (
                  <button
                    key={hex}
                    type="button"
                    className={'hs-chip' + (hex === shown && !inherit?.active ? ' is-on' : '')}
                    style={{ background: hex, color: readableInk(hex) }}
                    onClick={() => pickChip(hex)}
                    title={hex}
                  />
                ))}
              </div>
            </>
          )}

          {(free || inherit) && (
            <div className="hs-hexrow">
              {free && (
                <input
                  className="hs-hex"
                  dir="ltr"
                  value={text}
                  spellCheck={false}
                  maxLength={7}
                  placeholder="#RRGGBB"
                  aria-label={t('settings.pickHex')}
                  title={t('settings.pickHex')}
                  onChange={(e) => {
                    const v = e.target.value;
                    setText(v);
                    if (FULL_HEX.test(v.trim())) onChange(normHex(v, exact));
                  }}
                  onBlur={() => commitText(false)}
                  onKeyDown={(e) => { if (e.key === 'Enter') commitText(true); }}
                />
              )}
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
          )}
        </div>
      ), document.body)}
    </div>
  );
}
