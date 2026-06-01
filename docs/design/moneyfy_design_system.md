# Moneyfy Design System

Updated: 2026-05-30

This document is the source of truth for Moneyfy's product UI direction after the brand color, font, and token cleanup. Feature plans may describe local decisions, but reusable color, typography, spacing, surface, and guardrail rules should point back here.

## Direction

Moneyfy should feel like a calm personal finance product: white canvas, restrained dividers, clear financial hierarchy, and a fresh blue brand accent. The UI should stay dense enough for repeated portfolio work, but it should not become visually noisy through many unrelated colors.

Key principles:

- Primary brand color is icon blue, normalized to `#3A6DFF`.
- Color should communicate role first: brand, semantic state, neutral surface, chart category, or asset identity.
- Financial up/down semantics are text or icon accents, not filled warning cards.
- Most screens use white surfaces and quiet borders; heavy shadows and decorative gradients are avoided.
- Typography uses SUIT through app tokens. Direct font families, font weights, and page-level font sizes should not be introduced.
- Mobile screenshots at 360, 390, and 430dp are used to protect layout, density, and overflow behavior.

## Token Sources

| Role | Source |
| --- | --- |
| Brand and semantic colors | `lib/design_system/spec/visual_spec.dart`, `lib/theme/moneyfy_colors.dart` |
| Theme wiring | `lib/design_system/app_theme.dart`, `lib/theme/moneyfy_theme.dart` |
| Typography styles | `lib/design_system/app_typography.dart` |
| Font family tokens | `lib/design_system/font_families.dart` |
| Font weight tokens | `lib/design_system/font_weights.dart` |
| Spacing and size extensions | `lib/design_system/tokens.dart`, `lib/design_system/context_extensions.dart` |
| Guardrail script | `tools/check_design_token_guardrails.sh` |

## Brand Palette

| Token | Hex | Role |
| --- | --- | --- |
| Primary | `#3A6DFF` | Main brand action, selected navigation, links, primary charts |
| Primary Active | `#2DA4FF` | Pressed/active brand state and dark primary container |
| On Primary | `#FFFFFF` | Text or icon on primary fills |
| Success | `#00D47E` | Positive state, profit, completed status |
| Warning | `#FFB800` | Attention state that is not destructive |
| Error | `#FF4554` | Negative state, loss, destructive action |
| Ink | `#0A0B0D` | Primary text and deep trust neutral |
| Body | `#5B616E` | Secondary text |
| Muted | `#7C828A` | Tertiary text, low-emphasis labels |
| Disabled / Soft Text | `#A8ACB3` | Disabled text and dark muted text |
| Border | `#DEE1E6` | Default divider and outline |
| Soft Neutral | `#EEF0F3` | Subtle container, status container, icon plate |
| Surface Muted | `#F7F7F7` | Low-emphasis background band |
| Canvas | `#FFFFFF` | App background and card base |

Palette artifacts:

- `docs/brand/moneyfy_color_palette.svg`
- `docs/brand/moneyfy_color_palette.png`
- `docs/brand/moneyfy_current_app_color_audit.svg`
- `docs/brand/moneyfy_current_app_color_audit.png`

## Color Rules

### Brand

- Use `MoneyfyPalette.primary`, `ColorScheme.primary`, or `context.colors.primary` for brand actions.
- Do not reintroduce the old `#0052FF` primary in app UI. It was replaced by `#3A6DFF`.
- Do not create a separate "icon blue" token for UI. Icon blue and primary are unified.
- `#2DA4FF` is an active/pressed brand state, not a second primary.

### Semantic State

- Use success, warning, and error tokens only for state communication.
- Success: positive returns, completed states, confirmation indicators.
- Warning: attention or review-needed states.
- Error: destructive actions, validation errors, negative returns.
- Semantic colors should usually appear as text, icon, border, or small accent. Avoid large filled cards unless the surface is intentionally a status container.

### Surface and Text

- Default page and card surfaces are white.
- Use `#F7F7F7` for low-emphasis bands or background sections.
- Use `#EEF0F3` for subtle containers, icon plates, and soft status containers.
- Use `#DEE1E6` for borders and dividers.
- Primary text is `#0A0B0D`; secondary text is `#5B616E`; tertiary text is `#7C828A`.

### Chart and Asset Identity

- Reusable chart palettes are allowed because asset/category distinction needs more colors than the brand palette.
- Asset type colors are role-locked in `MoneyfyChartPalette.assetColors`.
- Individual asset colors may be derived from deterministic seeds through `MoneyfyChartPalette.colorForAsset`.
- Chart colors should not become general UI colors.

## Typography

Moneyfy uses SUIT for display, body, button, and numeric roles.

| Token | Family | Size | Weight | Line Height | Role |
| --- | --- | ---: | --- | ---: | --- |
| `pageTitle` | SUIT | 32 | regular | 1.12 | Page titles |
| `heroNumber` | SUIT | 36 | medium | 1.10 | Main financial number with tabular figures |
| `sectionTitle` | SUIT | 18 | semibold | 1.30 | Section headers |
| `cardTitle` | SUIT | 16 | semibold | 1.35 | Card and row title |
| `body` | SUIT | 16 | regular | 1.50 | Default body |
| `meta` | SUIT | 14 | regular | 1.43 | Metadata and helper text |
| `caption` | SUIT | 13 | regular | 1.30 | Compact labels |
| `button` | SUIT | 16 | semibold | 1.00 | Button labels |

Font tokens:

| Token | Value |
| --- | --- |
| `AppFontFamilies.sans` | `SUIT` |
| `AppFontFamilies.display` | `SUIT` |
| `AppFontFamilies.mono` | `SUIT` |
| `AppFontWeights.regular` | `FontWeight.w400` |
| `AppFontWeights.medium` | `FontWeight.w500` |
| `AppFontWeights.semibold` | `FontWeight.w600` |
| `AppFontWeights.bold` | `FontWeight.w700` |

Typography rules:

- Use `context.typography` or theme text styles for screen UI.
- Use `context.fontSizes` only when a reusable typography token does not fit.
- Use `AppFontWeights` instead of direct `FontWeight.w...`.
- Do not reference `.SF Pro`, Roboto, AppleSDGothic, Pretendard, or Noto directly in app UI.
- Letter spacing is `0` unless a specific token defines otherwise.
- Financial numbers should use tabular figures where available.

## Spacing and Surfaces

| Token | Value | Role |
| --- | ---: | --- |
| `xs` | 8 | Compact gaps |
| `sm` | 12 | Small internal spacing |
| `md` | 20 | Default card/content rhythm |
| `lg` | 24 | Page and grouped spacing |
| `xl` / `sectionGap` | 32 | Section separation |
| `xxl` | 48 | Large vertical separation |
| `xxxl` | 96 | Rare major separation |
| `pageTop` | 24 | Page top inset |
| `pageBottomInset` | 132 | Bottom navigation safe space |

Responsive horizontal padding:

| Width | Padding |
| ---: | ---: |
| `<= 360dp` | 14 |
| `<= 430dp` | 16 |
| `> 430dp` | 24 |

Surface rules:

- Cards use `VisualSpec.surface.radiusCard` (`16`) unless a component has a documented reason.
- Sheets and dialogs use `VisualSpec.surface.radiusSheet` (`24`).
- Default card padding is `20`, but mobile card padding can collapse to `16`.
- Rows should keep stable heights and avoid text overlap at 360dp and text scale 1.3.

## Component Rules

| Component Area | Rule |
| --- | --- |
| Primary button | Brand primary fill, white label, 44dp or taller tap target |
| Secondary button | Neutral tonal surface, not another blue fill |
| Destructive button | Error token, used only for destructive actions |
| Cards | White or muted neutral surface with restrained border |
| Rows | Stable height, clear leading identity, trailing financial value aligned |
| Chips and badges | Neutral background with semantic text or border where needed |
| Empty states | Tokenized icon/text color, no hard-coded gray |
| Forms | Theme input decoration, tokenized border/focus/error state |
| News cards | Long Korean title/body must wrap without overlap |
| Charts | Use chart palette and chart spec only inside chart/legend context |

## Platform Assets

- Obsolete generated launcher assets were removed from the repo.
- The app currently avoids keeping duplicate launcher icon sets in multiple platform folders.
- Platform asset changes are tracked in `docs/features/simple_patches/design_md_full_compliance/platform_asset_audit_report.md`.
- Web manifest theme color follows the current primary `#3A6DFF`.

## Guardrails

Run these checks when touching UI, theme, typography, or screenshots:

```bash
tools/check_design_token_guardrails.sh
tools/check_design_token_guardrails.sh --self-test
flutter analyze <changed dart files>
```

For broader design changes:

```bash
flutter test test/design_md_screenshot_harness_test.dart
flutter test test/page_walkthrough_test.dart
flutter test test/ui_component_smoke_test.dart
```

Screenshot regeneration:

```bash
MONEYFY_CAPTURE_DESIGN_MD_SCREENSHOTS=1 flutter test test/design_md_screenshot_harness_test.dart
```

Current guardrail intent:

- Report direct `Color(0x...)` and `Colors.*` outside token/theme sources.
- Report direct `fontSize:` outside design system/theme sources.
- Report direct or legacy font family references outside font tokens.
- Report direct `FontWeight.w...` outside font weight tokens.
- Report common direct spacing patterns that should use spacing tokens.

Allowed exceptions:

| Area | Reason |
| --- | --- |
| `lib/design_system/**` | Token source |
| `lib/theme/**` | Compatibility bridge and theme wiring |
| Platform assets | Native resource review, not Flutter token usage |
| Chart geometry | Numeric drawing geometry is allowed; color/type should still use tokens |
| Flutter intrinsic values | API-required constants may be used when documented |

## Do

- Use token names in code and docs instead of raw hex values.
- Keep primary blue scarce and purposeful.
- Keep semantic green/red/yellow tied to state meaning.
- Prefer quiet neutral surfaces over colored containers.
- Verify 360dp and 430dp behavior when changing dense financial screens.
- Update this document when a reusable token or design rule changes.

## Don't

- Do not add a new page-level hex color because it "looks close."
- Do not use chart colors for buttons, cards, or badges outside chart context.
- Do not use success/error as large background fills for ordinary profit/loss rows.
- Do not add direct font families, font weights, or local typography scales.
- Do not re-add deleted duplicate icon assets unless the platform icon pipeline is intentionally restored and documented.
- Do not use decorative gradients, heavy shadows, or large rounded marketing cards in operational app screens.

## Open Follow-Ups

- Pixel-level golden diff is not yet enforced.
- Real OS keyboard screenshots are still a manual QA gap.
- Additional loaded-state coverage is still useful for snapshot detail, target allocation sheet, and cash transaction form.
