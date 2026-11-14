---
name: notes
description: The user's personal wiki at ~/Notes (Obsidian-format markdown, zk link index, qmd search). Use when the user asks to note, save, file, remember, research or look something up in their notes, ingest a link or source, promote an idea, or lint the vault.
---

# Notes vault

The vault is `~/Notes`, a git repo of Obsidian-flavoured markdown.

1. Read `~/Notes/AGENTS.md` first. It holds the layout, frontmatter, lookup order, lifecycle and git rules. Follow it exactly.
2. Run vault commands from inside `~/Notes` (`cd ~/Notes && ...`): `zk` and `qmd` find their config there.
3. Start with `git -C ~/Notes pull --rebase`. Finish with `bin/reindex`, a `log.md` entry and a commit plus push.
4. Look things up cheapest first: `index.md` files, then `zk list` summaries, then `qmd query`. Never read or grep the whole vault.
5. `~/Notes/private/` is read only: change it only when the user explicitly asks in this session.
6. Note syntax (wikilinks, callouts, embeds, properties): the `obsidian-markdown` skill. Web pages into sources: the `defuddle` skill.
