# Assets

Source files behind the firmware and the README. The firmware never reads them
at runtime: fonts and icons are converted to C arrays under `firmware/src/`.

| Folder | What | Converted by |
|---|---|---|
| `design/` | Anthropic's design system spec | mapped by hand in `docs/design-system.md` |
| `fonts/anthropic-sans/` | Anthropic Sans, the full family (Display and Text cuts) | `tools/gen_fonts.sh` |
| `fonts/DejaVuSansMono.ttf` | spinner glyphs for the status line | `tools/gen_fonts.sh` |
| `icons/` | Lucide icons (SVG, plus PNG at each size) and the logos | `tools/png_to_lvgl.js` |
| `sounds/` | the reset chime | |
| `demo/` | demo images and video | |
| `readme/` | GIFs embedded in the main README | |

The fonts and the Clawd art belong to Anthropic. See the licensing warning in
the main README.
