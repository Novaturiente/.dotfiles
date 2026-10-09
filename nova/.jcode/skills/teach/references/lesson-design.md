# Lesson page design

Read with `lesson-format.md` when building a browser lesson. The template (`assets/lesson-template.html`) already applies the visual rules. Your job is the **content**: it decides whether the page feels inviting or like homework.

## Design read

A self-study lesson for one learner (any subject), in a dark terminal setup. It should feel **calm, focused and encouraging**: a good textbook page, not a landing page. No hype, no gamification, no confetti.

| Dial | Value | Meaning |
|---|---|---|
| Variance | 4 | Steady reading column, outline on the left |
| Motion | 3 | Only state changes animate (answered, selected, progress) |
| Density | 4 | Room to think, nothing crammed |

## Visual system (already in the template, do not override)

- **Palette:** Catppuccin Mocha neutrals, so it matches the terminal. **One accent: peach `#fab387`**, used for progress, selection, focus, answered marks and the Submit button. Red only for errors. No purple glow, no gradients.
- **Type:** SF Pro Display for text, ZedMono Nerd Font for code. Body 17px, reading width 70ch.
- **Shape:** cards 12px, inputs and code 8px, small controls 6px. Nothing else.
- **Code colours:** same token colours as the pi terminal theme, so code looks the same in chat and on the page.
- **Motion:** 0.2-0.5s ease-out on `transform`, `opacity`, colours and borders only. All motion is off under `prefers-reduced-motion`.
- **Accessibility:** every input has a visible label above it, focus rings use the accent, buttons say what they do.
- **Dark only.** It mirrors the terminal; a light theme would need a Catppuccin Latte token set.

## Content rules (your part)

### Page shape

1. `<h1>`: what they will be able to do, in plain words. "For loops in Python", not "Mastering Iteration".
2. `<p class="goal">`: one sentence, starting "By the end you will...". This is the reason to keep going.
3. Short explanation with one worked example. One `<div class="key">` holding the single idea to remember.
4. `<h2>` sections (2-4). Each becomes an entry in the outline rail.
5. 3-6 exercises, easy to hard, mixed types. End with `explain-back` when the idea is new.

The template adds the meta line, outline, progress bar, numbering and the Send panel. Do not write those yourself.

### Copy

- Plain, warm, direct. Write like a patient friend who knows the subject, not a course brochure.
- Encourage effort, not talent: "Take a guess first" beats "You've got this!".
- No filler verbs (master, unlock, elevate, seamless, journey). No fake numbers or time estimates.
- **No em-dashes or en-dashes anywhere.** Use a colon, comma, full stop or brackets.
- No emoji. No uppercase labels. No exclamation marks in instructions.
- Exercise prompts are one sentence and say exactly what to produce ("Write every line it prints").
- Examples use realistic, specific data (`["Ana", "Bo"]`, `prices = [4.5, 12, 7.25]`), not `foo`/`bar`.

### What makes it inspiring

- **A clear goal up top** and visible progress: learners keep going when they can see where they are.
- **One key idea per section**, so the page has a spine instead of a wall of text.
- **Small wins early:** the first exercise should be solvable from the worked example alone.
- **A real-world hook:** one line on where this is used ("Every playlist app loops over songs like this").
- **No answers on the page.** The feedback comes in chat, after they commit.

## Pre-flight check before opening the page

- [ ] `h1` + `p.goal` present, goal starts "By the end you will".
- [ ] Exactly one `.key` per section at most.
- [ ] Every `<code>` block has `class="language-xxx"`; every `complete`/`order` div has `data-lang` (`plaintext` for non-code).
- [ ] 3-6 exercises, at least 3 types, first one easy.
- [ ] No `—`, `–`, emoji, or hint text that gives an answer away.
- [ ] `<`, `>`, `&` escaped inside `<code>` and `<li>`.
