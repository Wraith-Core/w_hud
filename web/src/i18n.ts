/* ============================================================================
 * w_hud · i18n.ts -- the page's strings, as Lua hands them over
 *
 * ═══ The rule ═══
 *
 *   The page carries no text of its own. The library (w_lib) decides the language --
 *   Arabic or English -- and client/metabolism.lua sends the `ui.*` section of
 *   locales/{ar,en}.json here as { action: 'setLocale', locale, dir, strings }, once
 *   when the page announces itself (w_hud:ready) and again on every switch in /w_lib.
 *
 *   A key that is missing comes back as the key itself, so a hole in the dictionary is
 *   visible on screen rather than silently English.
 * ============================================================================ */

import { useSyncExternalStore } from 'react';

export type Strings = Record<string, string>;
export type TFn = (key: string) => string;

interface LocaleState {
  lang: 'ar' | 'en';
  dir: 'rtl' | 'ltr';
  strings: Strings;
}

let state: LocaleState = { lang: 'en', dir: 'ltr', strings: {} };
const listeners = new Set<() => void>();

/** Called from the NUI message handler with what Lua sent. */
export function applyLocale(msg: { locale?: unknown; dir?: unknown; strings?: unknown }): void {
  const lang = msg.locale === 'ar' ? 'ar' : 'en';
  const dir = msg.dir === 'rtl' || (msg.dir == null && lang === 'ar') ? 'rtl' : 'ltr';
  const strings: Strings = {};

  if (msg.strings && typeof msg.strings === 'object') {
    for (const [k, v] of Object.entries(msg.strings as Record<string, unknown>)) {
      if (typeof v === 'string') strings[k] = v;
    }
  }

  state = { lang, dir, strings };
  document.documentElement.dir = dir;
  document.documentElement.lang = lang;

  for (const fn of listeners) fn();
}

/** The current translation of `key` (the key itself when missing). */
export const t: TFn = (key) => state.strings[key] ?? key;

const subscribe = (fn: () => void) => {
  listeners.add(fn);
  return () => { listeners.delete(fn); };
};

const snapshot = () => state;

/** The language, direction and translator -- re-renders the caller on every switch. */
export function useI18n(): LocaleState & { t: TFn } {
  const s = useSyncExternalStore(subscribe, snapshot, snapshot);
  return { ...s, t: (key) => s.strings[key] ?? key };
}
