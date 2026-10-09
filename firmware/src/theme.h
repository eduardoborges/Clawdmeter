#pragma once
#include <lvgl.h>

// Design tokens: the dark surfaces of Claude's design system (DESIGN.md
// "surface-dark" family) on a true black floor, which leaves AMOLED pixels off.
// Coral is Claude Code's own accent rather than claude.com's #cc785c.
#define THEME_BG       lv_color_hex(0x000000)   // screen floor
#define THEME_PANEL    lv_color_hex(0x1f1e1b)   // surface-dark-soft: cards
#define THEME_TEXT     lv_color_hex(0xfaf9f5)   // on-dark
#define THEME_DIM      lv_color_hex(0xa09d96)   // on-dark-soft
#define THEME_ACCENT   lv_color_hex(0xd97757)   // coral
#define THEME_RED      lv_color_hex(0xc64545)   // error: a limit close to running out
#define THEME_BAR_BG   lv_color_hex(0x252320)   // surface-dark-elevated: tracks, badges
