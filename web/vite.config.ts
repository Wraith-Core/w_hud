import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
// Every px in the CSS follows the screen (720p .. 8K, ultrawide by height): ui-scale.cjs.
import uiScale from './ui-scale.cjs';

// Strip crossorigin from the injected <script>/<link> tags -- inside RedM CEF a module
// request can fail in CORS mode over nui:// (the most common cause of a black screen).
// Removing it makes the load plain same-origin, which always works.
const stripCrossorigin = () => ({
  name: 'strip-crossorigin',
  enforce: 'post' as const,
  transformIndexHtml(html: string) {
    return html.replace(/\s+crossorigin(=("|')?.*?\2)?/g, '');
  },
});

// 2.2.0: the settings panel is drawn with the board kit (src/kit.css, a byte-identical copy of the other
// resources' one), whose sizes are in rem = 20 design px. The HUD keeps its own small root size (hud.css:
// html = 6.912 design px, the size of the game's cores), so in the kit and the panel's sheet every rem is
// written as design px here, before ui-scale turns each px into calc(N * var(--ws-px)). Only those two
// files are touched; the kit file itself stays identical on disk.
const KIT_REM_PX = 20;
const KIT_FILES = /[\\/]src[\\/](kit\.css|settings[\\/]board\.css)$/;
type CssRoot = { source?: { input?: { file?: string } }; walkDecls: (fn: (d: { value: string }) => void) => void };
const kitRem = () => ({
  postcssPlugin: 'w_hud-kit-rem',
  Once(root: CssRoot) {
    const file = root.source?.input?.file || '';
    if (!KIT_FILES.test(file)) return;
    root.walkDecls((decl) => {
      if (!decl.value.includes('rem')) return;
      decl.value = decl.value.replace(/(-?\d*\.?\d+)rem\b/g,
        (_m: string, n: string) => `${+(Number(n) * KIT_REM_PX).toFixed(4)}px`);
    });
  },
});

export default defineConfig({
  plugins: [react(), stripCrossorigin()],
  base: './',
  css: { postcss: { plugins: [kitRem(), uiScale()] } },
  build: {
    outDir: 'build',
    // build/ also holds the static textures, fonts and pngs the HUD loads by path (no public/
    // folder): Vite must not wipe them before writing assets/
    emptyOutDir: false,
    // A CEF-compatible target (instead of esnext) -- avoids any syntax newer than the game browser
    target: ['chrome87', 'edge88', 'firefox78', 'safari14'],
    minify: true,
    cssCodeSplit: false,
    // Fixed filenames (no hash) -- so RedM does not need a refresh with every build
    rollupOptions: {
      output: {
        entryFileNames: 'assets/app.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: (info) =>
          info.name && info.name.endsWith('.css') ? 'assets/app.css' : 'assets/[name][extname]',
      },
    },
  },
});
