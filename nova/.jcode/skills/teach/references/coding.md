# Coding pack

Read this when the subject is programming. It adds to `SKILL.md`, it does not replace it.

## The learner types the code

- Never write code into the learner's project files. Show it in chat; they type it.
- When they ask for the full solution: give it in chat, have them type it, then ask them to explain one or two key lines back.
- The code you show should model good taste: the smallest working solution, the standard library first, no speculative abstraction, clear names. That is the style the learner absorbs.

## Code in chat

- **Every code block names its language** (` ```python `, ` ```js `, ` ```bash `). Most terminals and chat views only colour tagged blocks, and untagged code is hard to read for a beginner.
- Keep chat snippets short (under ~15 lines). Longer worked examples go on a lesson page, which has highlighting and line numbers.

## Versions and research

- Read exact versions from the lockfile or manifest (`package-lock.json`, `uv.lock`, `Cargo.lock`, `go.sum`) or with `<tool> --version`. Teach the API of *that* version.
- If a package is newer than what you know well, read its changelog or migration guide before explaining it. Note breaking changes in the brief's "Project context".
- When an error appears, search the exact message plus the package and version before guessing at a fix.
- Before installs, upgrades or OS-specific setup, check the official install docs for the current steps.

## Generation exercises for code

- **Predict:** "What will this print?" then run it and show the real output.
- **Find it:** "Open `file.py` and find where X happens." Fade the hint: line number, then function name, then "where would you look?"
- **Debug this:** show a plausible bug, ask what breaks and why.
- **Complete / order** (browser): fill blanks in code, or arrange shuffled lines (Parsons problems).

## Reviewing their code

When they say they are done:
1. Read the file and run it (or its tests). Show the real output.
2. Point to the line, say what is wrong or could be simpler, and ask them to fix it.
3. When it works, name one thing done well and one improvement: less code, standard library, clearer name.
4. Add the file and what it does to "Done in the project" in `.teach/progress.md`.
