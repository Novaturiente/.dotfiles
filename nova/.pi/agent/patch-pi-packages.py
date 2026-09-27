#!/usr/bin/env python3
"""Re-apply local tweaks to installed pi packages. Idempotent; rerun after `pi update` / reinstall.

1. pi-powerline-footer: model segment shows `opus:med` instead of `opus · [med]`.
2. @rokiy/pi-ui: drop its footer so powerline owns the status row
   (also hides the extra status line with pi-lens "LSP Inactive").
"""
import pathlib, sys

NM = pathlib.Path.home() / ".pi/agent/npm/node_modules"

PATCHES = [
    (
        "pi-powerline-footer/segments.ts",
        [
            ("const thinkingText = getThinkingText(level);",
             'const thinkingText = getThinkingText(level)?.replace(/[\\[\\]]/g, "").trim();'),
            ("content += `${SEP_DOT}${thinkingText}`;", "content += `:${thinkingText}`;"),
        ],
    ),
    (
        "@rokiy/pi-ui/src/ui.ts",
        [
            ("""  ctx.ui.setFooter((tui, theme, footerData) => ({
    dispose: footerData.onBranchChange(() => tui.requestRender()),
    render(width: number) {
      rerenderFooter = () => tui.requestRender();
      const usage = collectUsage(ctx);
      const coreSections = buildCoreFooterSections(theme, footerData, ctx, pi, usage);
      const lines = [renderCoreFooterLine(width, theme, coreSections)];
      const extensionLine = renderExtensionStatusLine(width, theme, footerData);

      if (extensionLine) {
        lines.push(extensionLine);
      }

      return lines;
    },
    invalidate() { },
  }));""",
             """  // ponytail: pi-ui footer disabled locally so powerline owns the status row.
  // Re-enable by restoring this setFooter call. Reinstall of @rokiy/pi-ui reverts this.
  void collectUsage; void buildCoreFooterSections; void renderCoreFooterLine; void renderExtensionStatusLine; void pi;"""),
        ],
    ),
]

failed = False
for rel, edits in PATCHES:
    f = NM / rel
    if not f.exists():
        print(f"skip (not installed): {rel}")
        continue
    s = f.read_text()
    for old, new in edits:
        if new in s:
            continue
        if old not in s:
            print(f"FAIL {rel}: upstream text changed, patch by hand")
            failed = True
            continue
        s = s.replace(old, new)
    f.write_text(s)
    print(f"ok {rel}")
sys.exit(1 if failed else 0)
