# Browser lesson format

Read this only when building a browser lesson. Chat and quick questions do not need it. Paths below are relative to the skill folder, written `<skill>/`. In jcode that is `~/.jcode/skills/teach`. Also read `lesson-design.md` for the content and copy rules that make the page feel inviting.

## Steps

1. Pick a topic slug: lowercase letters, digits, hyphens (`python-loops`).
2. Write **only the lesson body** to `/tmp/teach-lessons/<slug>/lesson.html`. No `<html>`, `<head>`, CSS or JS: the server wraps it in `assets/lesson-template.html`, which adds highlighting, line numbers, the outline rail, progress, widgets, confidence buttons and the Submit panel.
3. Make sure the server is running (one per session). The command is `python3 <skill>/scripts/lesson_server.py`; it prints `SUBMITTED <slug> <path>` on every submit.
   - Already running? Reuse it. Check your harness's process list if it has one, else `curl -s http://127.0.0.1:8765/ >/dev/null && echo up`.
   - Port 8765 taken by something else (`ss -ltn | grep 8765`, or `lsof -i :8765` on macOS) → tell the learner, do not kill it.
   - **Harness has a background-process tool that can wake you on a log line** (pi: `process start`, name `teach-lessons`, `notify.logMatches: [{pattern: "SUBMITTED", on: "turn", repeat: true}]`): use it.
   - **jcode:** start the server detached (next bullet). Then, per lesson, run a waiter with `bash` + `run_in_background: true`, `wake: true`: `tail -n0 -F /tmp/teach-lessons.log | grep -m1 "SUBMITTED <slug>"`. It finishes, and wakes you, when the learner submits.
   - **Otherwise** start it detached from the shell: `nohup python3 <skill>/scripts/lesson_server.py >/tmp/teach-lessons.log 2>&1 &`.
4. Open it: `xdg-open http://127.0.0.1:8765/<slug>/` on Linux, `open ...` on macOS. If no browser can be opened, give the learner the URL.
5. Tell the learner in one or two lines what the page covers. If you get woken on submit, say you will reply once they click **Submit**. If not, ask them to click **Submit** and then type "submitted" in chat. End your turn. Do not poll.
6. On the `SUBMITTED` notice or the learner's "submitted", read `/tmp/teach-lessons/<slug>/answers.json` and give feedback in chat (see "Feedback" below).

No way to run a background process at all? Skip the page and use chat questions instead (see "Asking questions" in `SKILL.md`).

## Body building blocks

Escape `<`, `>` and `&` as `&lt;`, `&gt;`, `&amp;` inside `<code>` and `<li>`. The one exception is `<textarea>` content, which needs no escaping except that it must not contain `</textarea>`.

### Heading, goal and explanation

```html
<h1>For loops in Python</h1>
<p class="goal">By the end you will be able to repeat code once for every item in a list.</p>
<h2>Looping over a list</h2>
<p>A <strong>for loop</strong> runs its body once per item.</p>
<div class="key"><p>The indented lines under <code>for</code> are the loop body. They run once per item.</p></div>
<pre><code class="language-python">for name in ["ana", "bo"]:
    print(name)</code></pre>
```

Always set `class="language-xxx"` on code blocks; for non-code material (sentences, equations, steps) use `language-plaintext`, or skip the `<pre>` and use normal paragraphs. Keep explanation short: one idea, one example, then an exercise. `p.goal` must follow the `h1` directly. Each `h2` becomes an outline entry; `div.key` renders as a "Key idea" box.

### Exercises

Every exercise is a `<div class="ex TYPE">` whose **first `<p>` is the prompt** (it is saved with the answer). Give each a stable `id` so feedback can refer to it. The template numbers them and adds the type label, so do not write "Exercise 1" yourself.

| Type | Use for | Markup inside the div |
|---|---|---|
| `quiz` | Multiple choice; misconceptions as wrong options | `<p>` prompt, optional `<pre><code>`, then `<ul><li>` options (may contain `<code>`) |
| `predict` | "What does this print?", "What happens if...?" | `<p>` prompt + `<pre><code>` snippet. Answer box is added for you |
| `complete` | Fill in missing code, words or steps | `<p>` prompt + `<textarea>` with starter text, `___` marking blanks. Add `data-lang="python"` (or `"plaintext"`) on the div |
| `order` | Arrange shuffled lines or steps (Parsons problem for code) | `<p>` prompt + `<ol><li>` items **in the correct order** (the page shuffles them). Keep indentation. Add `data-lang` (`"plaintext"` for non-code) |
| `explain-back` | Teach-it-back in their own words | `<p>` prompt only |

```html
<div class="ex quiz" id="q-range">
  <p>What does <code>list(range(3))</code> give?</p>
  <ul><li><code>[1, 2, 3]</code></li><li><code>[0, 1, 2]</code></li><li><code>[0, 1, 2, 3]</code></li><li>Not sure yet</li></ul>
</div>

<div class="ex complete" id="c-sum" data-lang="python">
  <p>Fill the blanks so <code>total</code> ends as the sum of <code>nums</code>.</p>
  <textarea>total = 0
for n in ___:
    total ___ n
print(total)</textarea>
</div>

<div class="ex order" id="o-evens" data-lang="python">
  <p>Order the lines to print only even numbers below 6.</p>
  <ol><li>for i in range(6):</li><li>    if i % 2 == 0:</li><li>        print(i)</li></ol>
</div>
```

## Choosing the mix

- 3-6 exercises per page. More than that turns into cramming.
- Mix types on the same concept (quiz → predict → complete → order). Varied practice transfers better than repeating one format.
- Order easy to hard. Put one `explain-back` last when the concept is new.
- Do not put answers or hints on the page.

## Feedback after submit

`answers.json` has `answers: [{id, type, prompt, answer, confidence}]`.

- Go exercise by exercise in chat, short: ✅ right / ❌ wrong + the one-line why.
- For `complete`, run their code when it is runnable and show the real output. For non-code answers, check each blank against the source.
- Record the score in the progress file's session log (see "Progress tracking" in `SKILL.md`).
- For `order`, compare to the correct order you wrote.
- Use `confidence`: **right but "guessed"** = not learned yet; **wrong but "sure"** = a misconception, the most valuable thing to fix. Name both explicitly.
- Then update the knowledge map and teach the first gap.
