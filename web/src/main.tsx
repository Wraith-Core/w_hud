import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './kit.css';        // 2.2.0: the board kit (the settings panel), first: the HUD's own sheets win the ties
import './hud.css';        // the HUD design
import './wheel/wheel.css'; // the weapon wheel (uses the same --tex-* variables below)
import './settings/settings.css'; // the free-layout wrapper and the editor's chrome
import './settings/board.css';    // 2.2.0: the control panel on the board kit

function diag(msg: string, ok: boolean) {
  const d = document.getElementById('__diag');
  if (!d) return;
  d.textContent = msg;
  // the theme's paper; a failure is told by the red mark on the edge, never by red text
  (d as HTMLElement).style.color = '#F2F2F2';
  (d as HTMLElement).style.borderColor = ok ? 'rgba(242,242,242,0.32)' : '#CB0101';
}

// -- 2.2.0: the faces are the board kit's, injected here (no longer w_lib's store theme): their path must be
//    relative to the build page, Vite would write absolute CSS paths that break under nui://.
//      EB Garamond    Latin text, labels and small figures   (SIL OFL 1.1)
//      Lalezar        every Arabic text: the role names (Amiri, Tajawal, Noto Sans Arabic) draw its file
//      RDR Lino       the server's name (the wordmark)
//      RDR Catalogue  the big figures: the wallet, the ammo
//    The torn edge, the grain and the selection band (the kit's --tex-*) are byte-identical copies of the
//    other boards' (w_train/web/public/tex).
try {
  const BASE = import.meta.env.BASE_URL || './';
  let ABS_BASE = BASE;
  try { ABS_BASE = new URL(BASE, document.baseURI).href; } catch { ABS_BASE = BASE; }

  const FONTS = `${ABS_BASE}fonts/`;
  const AR = 'U+0600-06FF,U+0750-077F,U+0870-088E,U+0890-0891,U+0897-08E1,U+08E3-08FF,U+FB50-FDFF,U+FE70-FE74,U+FE76-FEFC,U+200C-200E,U+2010-2011,U+0660-0669';
  const LALEZAR = `url("${FONTS}Lalezar-400-arabic.woff2") format("woff2")`;
  const faces = document.createElement('style');
  faces.textContent = `
    @font-face { font-family: "EB Garamond"; font-style: normal; font-weight: 400 800; src: url("${FONTS}EBGaramond-latin.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "Lalezar"; font-weight: 100 900; src: ${LALEZAR}; unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 400; src: ${LALEZAR}; unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 700; src: ${LALEZAR}; unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 400; src: ${LALEZAR}; unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 700; src: ${LALEZAR}; unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Noto Sans Arabic"; font-weight: 100 900; src: ${LALEZAR}; font-display: swap; }
    @font-face { font-family: "RDR Lino"; font-weight: 100 900; src: url("${FONTS}RDRLino-Regular.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "RDR Catalogue"; font-weight: 100 900; src: url("${FONTS}RDRCatalogueBold-Bold.woff2") format("woff2"); font-display: swap; }
  `;
  document.head.appendChild(faces);

  // the original RDR textures as CSS variables (absolute path -- works inside CEF)
  const root = document.documentElement.style;
  root.setProperty('--tex-panel', `url("${ABS_BASE}tex/ui/toast_bg.png")`);
  root.setProperty('--tex-bar', `url("${ABS_BASE}tex/ui/weapon_stats_bar.png")`);
  root.setProperty('--tex-bar-mask', `url("${ABS_BASE}tex/ui/weapon_stats_bar_mask.png")`);
  root.setProperty('--tex-divider', `url("${ABS_BASE}tex/ui/title_divider.png")`);
  root.setProperty('--tex-disc', `url("${ABS_BASE}tex/ui/help_text_bg.png")`);   // the black textured disc inside the rings
  root.setProperty('--tex-panel-ink', `url("${ABS_BASE}tex/ui/help_text_bg.png")`); // the wallet / identity plates (the wheel's dialog plate)

  // ★ The original RDR core icons (taken from w_lib/html/dist/assets).
  //   They are injected as a **mask**, not an image: the mask takes the image's shape and
  //   is coloured by background-color, so the icon stays colourable (white/yellow/red) and
  //   the two-layer system works with it exactly as with SVG icons. A plain image cannot be coloured.
  // The wallet's money icons are the game's own too (2026-10-22, the owner's picks): money_moneystack
  // (inventory_items), blip_robbery_bank (blips), blip_gold (blips_mp), log_gang_bag (menu_textures) --
  // white ink, their dark lines made see-through, so the row colour tints them like the cores.
  for (const n of ['player_health', 'player_health_broken', 'player_stamina', 'horse_health', 'food', 'drink',
    'money_cash', 'money_bank', 'money_gold', 'money_dirty'] as const) {
    root.setProperty(`--ic-${n}`, `url("${ABS_BASE}png/${n}.png")`);
  }

  // ★ The board kit's textures (the settings panel)
  root.setProperty('--tex-tear', `url("${ABS_BASE}tex/tear.png")`);
  root.setProperty('--tex-grain', `url("${ABS_BASE}tex/grain.png")`);
  root.setProperty('--tex-band', `url("${ABS_BASE}tex/band.png")`);
  root.setProperty('--tex-band-sm', `url("${ABS_BASE}tex/band-sm.png")`);

  // ★ The same visual language as w_crafting -- surface textures and divider lines
  for (const n of ['swatch_bg_1a', 'counter_bg_1a', 'menu_bar', 'divider_line', 'title_divider',
    'list_item_h_line_narrow', 'selection_box_bg_1c', 'crafting_outline',
    'vertical_divider_line'] as const) {
    root.setProperty(`--tex-${n}`, `url("${ABS_BASE}tex/ui/${n}.png")`);
  }
} catch (e) {
  /* ignore -- the fallback fonts are enough */
}

try {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );
  const d = document.getElementById('__diag');   // mounted successfully -> hide the diagnostic marker
  if (d) (d as HTMLElement).style.display = 'none';
} catch (e: any) {
  diag('w_hud REACT ERROR: ' + (e?.message || e), false);
}

