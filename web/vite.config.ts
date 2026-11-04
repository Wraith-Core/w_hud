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

// Keep the shared store visuals after Vite's generated application stylesheet.
const storeThemeLast = () => ({
  name: 'store-theme-last', enforce: 'post' as const,
  transformIndexHtml: { order: 'post' as const, handler(html: string) {
    const tag = html.match(/<link[^>]*data-wraith-store-theme[^>]*>/)?.[0];
    return tag ? html.replace(tag, '').replace('</head>', `${tag}\n</head>`) : html;
  } },
});

export default defineConfig({
  plugins: [react(), stripCrossorigin(), storeThemeLast()],
  base: './',
  css: { postcss: { plugins: [uiScale()] } },
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
