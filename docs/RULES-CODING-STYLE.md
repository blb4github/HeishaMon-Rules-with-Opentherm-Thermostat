# Coding and documentation style for HeishaMon Rules

This guide records the agreed conventions introduced in **Rules 2611.10**. Its purpose is maintainability and readability, not a new heat-pump control strategy.

## Authoritative source and workflow

- **Edit only `HeishaMon_Rules_BlB4_commented.lua`.** It is the maintained, annotated source. The `.lua` extension does not mean standard Lua; this is the HeishaMon Rules language.
- Generate `HeishaMon_Rules_BlB4.lua` with the [HeishaMon rules minifier](https://github.com/klaashoekstra94/heishamon_rules_minify) after changes. Do not hand-maintain the generated file.
- Keep descriptions of **current behavior and the reasons for non-obvious logic** in source comments. Record historical changes, release motivations and refactoring history in `CHANGELOG.md`.
- Preserve established Rule ordering, startup timing, conditions and calculations when performing a style-only change. Review proposed behavioral changes separately.

## Layout

| Element | Convention |
| --- | --- |
| Language | English for code documentation and comments |
| Tabs | **8-column tab stops**, matching the author's VS Code settings |
| Indentation | One tab per level; tabs only, not spaces |
| Inline comments | Place all trailing `--` comments **in one aligned column per Rule block** |
| Alignment | Use **tabs only** to reach the selected comment column; the column may differ from Rule to Rule |
| Line width | Target at most **160 displayed columns**, counting tab expansion to 8-column stops |
| Long expressions | Keep together when clear and within the width; split at logical condition or arithmetic boundaries when clarity benefits |
| Whitespace | Consistent spaces around binary operators and after commas; do not realign expressions using runs of spaces |
| Semicolons | Retain the existing HeishaMon Rules convention |
| Blank lines | Separate conceptual sections where helpful, without inserting a blank line after every statement |
| Rule order | Keep the existing Rule order and numbering unless a change is explicitly reviewed |

**Important:** a chosen comment column applies within one Rule, not across all Rules. A shorter Rule may use an earlier column than a complex one. Preserve the tabs when copying or editing; proportional-font previews may not display their alignment accurately.

## Rule documentation

Use a short header immediately before each Rule:

```lua
--[[
timer=10:	Weather Compensation
Purpose:	Calculate the weather-compensated heating baseline (#WCS).
Explanation:	Explain the calculation, important constraints and why any fixed values are needed.
Result:		#WCS, heating target in C.
Called by:	Scheduled from timer=1; repeats every 1800 seconds.
rule 14]]
```

- `Purpose`: what the Rule accomplishes, briefly.
- `Explanation`: how the Rule behaves and *why* noteworthy conditions and safeguards exist; accurate for the **current** implementation.
- `Result`: global variables and important control commands produced.
- `Called by`: actual event, initial scheduler and repeat interval.
- Keep the established `rule NN` identifier matched to its actual order.

Use **short trailing comments** for noteworthy constants and assignments. Use a **comment on a separate preceding line** for complex conditions, safeguards, exceptional transitions or groups of statements.

Do **not** add comments that simply repeat obvious code (for example, `setTimer(4,60); -- Repeat every minute` when the header already gives the interval). Do not duplicate explanations from the header. Explain the *reason* for a safeguard where this is less obvious than the action.

## Review and release checks

1. Review the canonical source first, including its comments, indentation, column alignment and Rule order.
2. For style-only edits, compare **executable tokens** with the preceding source and check that no expressions, commands, string literals, variables or conditions changed.
3. Minify from that accepted source. Confirm that the generated file contains the same executable tokens. Minification may change whitespace, but not code semantics; literal diagnostic strings should also match.
4. Check the installed HeishaMon build supports both `gpio(33)` and **more than 127 Rules variable slots** for versions 2611.08 onward.
5. Check conditional-jump offsets against the bytecode's **255-instruction limit**; this is independent of the 255-variable-slot capacity. Where supported, require a compile-time failure rather than accepting a truncated jump. See [2611.13 notes](TA-SHIFT-2611-13.md).
6. Review the Rules load log, slot/memory totals and runtime behavior separately. Successful minification or token comparison does not prove safe device behavior.
7. Document changed behavior in `CHANGELOG.md`, update `README.md` as required and submit a pull request for review. Do not merge unreviewed changes.

This guide describes the **2611.10 style baseline** and should evolve only by explicit agreement, not incidentally during functional modifications.
