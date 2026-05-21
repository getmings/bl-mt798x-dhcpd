/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Copyright (C) 2026 Yuzhii0718
 *
 * All rights reserved.
 *
 * This file is part of the project bl-mt798x-dhcpd
 * You may not use, copy, modify or distribute this file except in compliance with the license agreement.
 */

/**
 * Failsafe Theme Bootstrap
 *
 * Runs synchronously before main.js to apply cached theme preferences,
 * eliminating the flash of unstyled/wrong-theme content (FOUC).
 *
 * Self-contained — does not depend on main.js. main.js will later
 * re-apply and extend these settings via window-level hooks.
 */
(() => {
    "use strict";

    const STORAGE_KEYS = Object.freeze({
        theme: "theme",
        accent: "failsafe_theme_color_cache",
    });
    const TRANSITION_DURATION_MS = 600;
    const HEX_SHORT = /^[0-9a-f]{3}$/i;
    const HEX_FULL  = /^[0-9a-f]{6}$/i;

    /* ── Preferences ────────────────────────────────────────── */
    let prefersReducedMotion = false;
    let mqReducedMotion = null;
    try {
        mqReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
        prefersReducedMotion = !!mqReducedMotion?.matches;
    } catch { /* keep default */ }

    /* ── Helpers ─────────────────────────────────────────────── */
    const normalizeHex = (input) => {
        if (input == null) return null;
        let s = String(input).trim();
        if (!s) return null;
        if (s[0] === "#") s = s.slice(1);
        if (!HEX_SHORT.test(s) && !HEX_FULL.test(s)) return null;
        return s.length === 3
            ? `#${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}`.toLowerCase()
            : `#${s.toLowerCase()}`;
    };

    const hexToRgb = (hex) => {
        const n = normalizeHex(hex);
        if (!n) return null;
        return {
            r: parseInt(n.slice(1, 3), 16),
            g: parseInt(n.slice(3, 5), 16),
            b: parseInt(n.slice(5, 7), 16),
        };
    };

    const blendToWhite = (hex, t) => {
        const a = hexToRgb(hex);
        if (!a) return hex;
        const mix = (c) => Math.round(c + (255 - c) * t).toString(16).padStart(2, "0");
        return `#${mix(a.r)}${mix(a.g)}${mix(a.b)}`;
    };

    const readStorage = (key) => {
        try { return localStorage.getItem(key); }
        catch { return null; }
    };

    const applyThemeColorMeta = (color) => {
        if (!color) return;
        let meta = document.querySelector("meta[name='theme-color']");
        if (!meta) {
            meta = document.createElement("meta");
            meta.setAttribute("name", "theme-color");
            document.head?.appendChild(meta);
        }
        meta.setAttribute("content", color);
    };

    const getCachedAccent = () => normalizeHex(readStorage(STORAGE_KEYS.accent));

    /* ── Theme transition animation ──────────────────────────── */
    const setupTransition = (root) => {
        if (prefersReducedMotion) return;

        let timer = null;
        let ready = false;
        let lastAttr = root.getAttribute("data-theme");

        const pulse = () => {
            if (!ready) return;
            if (timer) { clearTimeout(timer); timer = null; }
            root.classList.add("theme-transition");
            timer = setTimeout(() => {
                root.classList.remove("theme-transition");
                timer = null;
            }, TRANSITION_DURATION_MS);
        };

        try {
            new MutationObserver(() => {
                const now = root.getAttribute("data-theme");
                if (now !== lastAttr) {
                    lastAttr = now;
                    if (!root.__failsafeThemeSilent) pulse();
                }
            }).observe(root, { attributes: true, attributeFilter: ["data-theme"] });
        } catch { /* MutationObserver unavailable */ }

        try {
            const mq = window.matchMedia("(prefers-color-scheme: dark)");
            const onChange = () => {
                if (root.getAttribute("data-theme-auto") === "1") {
                    applyThemeMode(root, "auto", false);
                }
            };
            mq.addEventListener?.("change", onChange) ?? mq.addListener?.(onChange);
        } catch { /* matchMedia unavailable */ }

        /* defer readiness so initial paint skips transition */
        setTimeout(() => { ready = true; }, 0);
    };

    /* ── Theme mode application ──────────────────────────────── */
    const getPreferredScheme = () => {
        try {
            return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
        } catch { return "light"; }
    };

    const applyThemeMode = (root, mode, silent) => {
        const schema = (mode === "light" || mode === "dark") ? mode : "auto";
        const isAuto = schema === "auto";
        const resolved = isAuto ? getPreferredScheme() : schema;

        const setAttr = () => {
            if (silent) root.__failsafeThemeSilent = true;
            if (isAuto) {
                root.setAttribute("data-theme-auto", "1");
            } else {
                root.removeAttribute("data-theme-auto");
            }
            root.setAttribute("data-theme", resolved);
            applyThemeColorMeta(getCachedAccent() ?? (resolved === "dark" ? "#070b16" : "#eef2f8"));
            if (silent) {
                setTimeout(() => { root.__failsafeThemeSilent = false; }, 0);
            }
        };

        /* double rAF batches layout before triggering transitions */
        if (!silent && !prefersReducedMotion && typeof requestAnimationFrame === "function") {
            requestAnimationFrame(() => requestAnimationFrame(setAttr));
        } else {
            setAttr();
        }
    };

    /* ── Bootstrap ───────────────────────────────────────────── */
    try {
        const root = document.documentElement;
        const cachedAccent = readStorage(STORAGE_KEYS.accent);
        const cachedTheme  = readStorage(STORAGE_KEYS.theme);

        setupTransition(root);

        /* apply cached theme mode (silent — no transition on load) */
        applyThemeMode(root, cachedTheme ?? "auto", true);

        /* expose for main.js */
        window.__failsafeThemeApplyMode = (mode, opts) => {
            applyThemeMode(root, mode, !!opts?.silent);
        };

        /* apply cached accent color */
        const accent = normalizeHex(cachedAccent);
        const rgb = accent ? hexToRgb(accent) : null;
        if (accent && rgb) {
            root.style.setProperty("--primary", accent);
            root.style.setProperty("--primary-rgb", `${rgb.r}, ${rgb.g}, ${rgb.b}`);
            root.style.setProperty("--primary-2", blendToWhite(accent, 0.28));
            applyThemeColorMeta(accent);
        }

        /* re-evaluate reduced motion if OS preference changes post-load */
        mqReducedMotion?.addEventListener?.("change", (e) => {
            prefersReducedMotion = e.matches;
        });
    } catch { /* fail silently — main.js will recover */ }
})();
