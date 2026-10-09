---
name: ponytail-help
description: >
  Quick reference for ponytail levels, skills and commands. One-shot display.
  Use for /ponytail-help, "ponytail help", "how do I use ponytail".
---

# Ponytail Help

Display this reference card when invoked. One-shot, do NOT change mode,
write flag files, or persist anything.

## Levels

| Level | Trigger | What change |
|-------|---------|-------------|
| **Lite** | `/ponytail lite` | Build what was asked, name the smaller option in one line. |
| **Full** | `/ponytail` | The smallest complete change, a check where the logic needs one, and a reply that names what was skipped and any risk. Default. |
| **Ultra** | `/ponytail ultra` | Also questions the request and pushes back before building. |

Level sticks until changed or session end.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **ponytail** | `/ponytail` | Lazy mode itself: least new code, clear replies that name skipped work and risks. |
| **ponytail-review** | `/ponytail-review` | Quality review of a diff: bugs, security, load, missing tests, speed, what to cut. Each finding says what goes wrong and how to fix it. |
| **ponytail-audit** | `/ponytail-audit` | The same quality review for the whole repo, ranked. |
| **ponytail-debt** | `/ponytail-debt` | Harvest `ponytail:` shortcut comments into a tracked ledger. |
| **ponytail-gain** | `/ponytail-gain` | Measured-impact scoreboard: less code, less cost, more speed. |
| **ponytail-help** | `/ponytail-help` | This card. |

In jcode, invoke any of them as a slash command (`/ponytail-review`), or let
jcode inject them when the conversation matches.

## Deactivate

Say "stop ponytail" or "normal mode" for the rest of the session. Resume with
`/ponytail`.

## Configure Default Mode (jcode)

Full mode is always on because its rules are in `~/.jcode/prompt-overlay.md`
(stowed from `~/.dotfiles/nova/.jcode/prompt-overlay.md`). To change the
default level, edit that file: replace its text with the lite or ultra rows
from `~/.jcode/skills/ponytail/SKILL.md`, or delete the section to turn
auto-activation off. Changes apply to new sessions.

## Update

These skills are a copy of the npm package `@dietrichgebert/ponytail`
(installed for pi under `~/.pi/agent/npm/node_modules/`). To update: update the
package, copy the six `skills/ponytail*` folders into
`~/.dotfiles/nova/.jcode/skills/`, re-apply the jcode edits to this file, and
regenerate the overlay section.

## More

Full docs + examples: https://github.com/DietrichGebert/ponytail
