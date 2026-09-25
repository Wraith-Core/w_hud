import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './hud.css';        // the HUD design
import './wheel/wheel.css'; // the weapon wheel (uses the same --tex-* variables below)
import './settings/settings.css'; // the control panel + the free-layout wrapper

function diag(msg: string, ok: boolean) {
  const d = document.getElementById('__diag');
  if (!d) return;
  d.textContent = msg;
  (d as HTMLElement).style.color = ok ? '#7CFC00' : '#ff4d4d';
  (d as HTMLElement).style.borderColor = ok ? '#7CFC00' : '#ff4d4d';
}

// -- the faces are the Wraith theme's (w_lib/nui/theme/fonts.css, pulled in by the store-theme.css link in
//    index.html): RDR Lino, Hapna Slab and RDR Catalogue for Latin, Lalezar / Amiri / Tajawal for Arabic --
//    the same files as the loading screen and the pause menu. Only the textures are set here.
try {
  const BASE = import.meta.env.BASE_URL || './';
  let ABS_BASE = BASE;
  try { ABS_BASE = new URL(BASE, document.baseURI).href; } catch { ABS_BASE = BASE; }

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
  for (const n of ['player_health', 'player_health_broken', 'player_stamina', 'horse_health', 'food', 'drink'] as const) {
    root.setProperty(`--ic-${n}`, `url("${ABS_BASE}png/${n}.png")`);
  }

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


import './store-adapter.css';
