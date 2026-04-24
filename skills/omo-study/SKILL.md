---
name: omo-study
description: Take a URL or a topic and teach it step-by-step, grounding every example in the user's accumulated Obsidian wiki context (projects, concepts, entities). Chooses examples and checkpoint questions by connecting to what the vault already knows. Every decision point — mode selection, per-step checkpoint (MCQ), step transitions, and wrap-up — flows through AskUserQuestion choice UIs. Use when the user says "/omo-study <URL or topic>", "teach me this", "walk me through X", "이거 가르쳐줘", "이거 이해하고 싶어".
origin: oh-my-obsidian
allowed-tools: Bash, Read, AskUserQuestion
---

# omo-study — wiki-context-grounded step-by-step learning

Take a URL or a topic, analyze it, and teach it step-by-step by anchoring every example in the user's existing projects and knowledge. Every decision point uses a **choice UI**.

## When to activate

- `/omo-study <URL>` — learn this page's contents
- `/omo-study <topic>` — learn this topic
- "teach me this", "walk me through X", "help me understand this"
- "이거 가르쳐줘", "이거 이해하고 싶어"

## Procedure

### Step 0: Pick a study mode (AskUserQuestion)

As soon as the input arrives, ask the user for the **study depth**.

**Question**:
- header: `Study mode`
- question: "How deep should we go?"
- multiSelect: false
- options:
  - label: `Quick overview` / description: "1–2 steps, fast tour"
  - label: `Standard` / description: "the recommended 3–5 steps"
  - label: `Deep dive` / description: "full project context + 5+ steps"

Store the choice as `MODE` and shape subsequent step count and context load based on it.

### Step 1: Content gathering

- For a URL: fetch the contents with Playwright + Defuddle (you may reuse the `clip.sh` pipeline).
- For a topic: gather the essentials via vault search + web search.
- Fully understand the content before moving on.

### Step 2: Load user context

Scale the context load to `MODE`:

| MODE            | Load scope                                                                 |
|-----------------|----------------------------------------------------------------------------|
| Quick overview  | Just 1–2 relevant project `index.md` files, quick scan                     |
| Standard        | `projects/*/index.md`, key `wiki/concepts/*.md`, `wiki/entities/*.md`      |
| Deep dive       | Entire project (worklog + decisions included), every concept/entity page  |

Identify the existing context the lesson can latch onto.

### Step 3: Explain step-by-step + MCQ checkpoint

Step count per mode:
- Quick overview: 1–2 steps
- Standard: 3–5 steps
- Deep dive: 5+ steps, scaled to content complexity

For each step:

1. **Explain the concept** — compactly state the core idea for this step.
2. **Ground in context** — link it to an analogous case in the user's projects.
3. **Checkpoint question (AskUserQuestion MCQ)** — ask a question the user must answer by applying or judging.

**Checkpoint rules**:

- **Force classification via multiple choice** — an MCQ organizes thinking better than free-text.
- **Never mark the correct option as "Recommended"** — learning requires the user to decide unaided.
- 2–4 options: 1 correct answer + 1–3 plausible distractors.
- Randomize option order (the correct option should not always be first).
- If the topic is tied to the user's projects, put a project-relevant option in. Otherwise use a general example.

**Question example**:
- header: `Check` (or the step's key term)
- question: "Which of our projects plays the most similar role to this?"
- multiSelect: false
- options:
  - label: `The LangGraph agent in nl2sql` / description: "state-driven workflow control"
  - label: `The tool-calling path in material-agent` / description: "LLM picks and runs tools"
  - label: `The pytorch training loop` / description: "plain iteration, not an agent"

(The user can always type "Other", so there's an escape hatch.)

**Answer handling**:

- **Correct** → "Correct. The reason is …" in one paragraph, then present the **step-transition UI** below.
- **Wrong** → Do not reveal the correct answer. Explain why it is wrong, then offer a **new MCQ from a different angle** until the user gets it right.
- **Free text via Other** → evaluate the key content and treat as correct/wrong.

**Step-transition UI (AskUserQuestion)**:

After confirming the correct answer, don't wait for a natural-language "next" — use a choice UI.

- header: `Next`
- question: "This step is done. How would you like to proceed?"
- multiSelect: false
- options:
  - label: `Next step` / description: "move to the next concept"
  - label: `More questions` / description: "ask more about this step"

(Free input via Other is still available.)

**Handling the choice**:

- **Next step** → begin the next step (explanation + context + MCQ). If it was the last step, go to Step 4 (final summary).
- **More questions** → prompt "What would you like to know?" for free input → after answering, **show the same step-transition UI again** (the user can chain several questions).
- **Other** → interpret the free input as the user's intent and act accordingly.

### Step 4: Final summary

After all steps, summarize everything in one paragraph. Briefly recap the user's choice history (e.g. "picked X correctly at step 1, retried after Y at step 3").

### Step 5: Wrap-up action (AskUserQuestion)

**Question**:
- header: `Next`
- question: "Study session is done. What's next?"
- multiSelect: false
- options:
  - label: `Save to wiki` / description: "store this session via /omo-ingest"
  - label: `Continue with related` / description: "chain into a related concept / entity /omo-study"
  - label: `End` / description: "wrap up here"

Handle the choice:

- **Save to wiki** → branch by input type (see "Save to wiki" below).
- **Continue with related** → suggest 2–3 related topics; when the user picks one, start a new `/omo-study` session.
- **End** → short sign-off and close the session.

### Step 5-1. "Save to wiki" handling

Branch based on whether the original input was a **URL** or a **topic**.

**URL input**:

→ Delegate to `/omo-ingest <original URL>`. The standard ingest pipeline will produce:

- `_sources/<category>/<slug>.md` — clip.sh original
- `wiki/summaries/<slug>.md` — summary
- Entity / concept / guide pages if warranted
- Registrations in `wiki/index.md`, `wiki/log.md` (log action: `ingest`)

Pass a note to `omo-ingest` like "this URL was just studied via `/omo-study`; fold the insights that emerged during the session into the summary", so the session takeaways land in the summary page.

**Topic input**:

→ Without an original URL, write `wiki/concepts/<topic-slug>.md` directly:

- Filename: the topic in kebab-case (e.g. "Differential Privacy" → `differential-privacy.md`)
- Frontmatter:
  ```yaml
  ---
  type: concept
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  status: active
  source-type: learning-session
  tags: [<related keywords>]
  aliases: [<original term>]
  ---
  ```
- Sections (per the Concept schema in `page-types.md`):
  - **Definition** — what the topic is, in one or two sentences
  - **Explanation** — the key mechanics covered in the session (integrate the full Step 3 content)
  - **Examples** (optional) — the contextual examples used during the session (project or general)
  - **Related concepts** — connected `[[wikilinks]]`
- Register under `## Concepts` in `wiki/index.md`
- Append to `wiki/log.md`:
  ```
  | YYYY-MM-DD | promoted | [[<topic-slug>]] | /omo-study learning session: <one-line summary> |
  ```

The `promoted` action marks content produced mid-conversation as permanentized. The originating skill (`/omo-study`) goes in the description column. The page's own `source-type: learning-session` frontmatter lets us filter learning-derived concepts later.

**Common**:

- After creation, report the file path back to the user.
- Add up to three `[[links]]` to related wiki pages (satisfies the minimum-one-link rule).

## Principles

- **Pick fitting examples** — if the topic ties directly to the user's stack / architecture / patterns, ground in a project. If the connection is weak, use an everyday analogy or a widely known technical case.
- **One thing at a time** — explain a single step, wait for the checkpoint answer, then advance.
- **Don't pre-reveal the answer** — no "(Recommended)" tag, no hint that gives the answer away before the user responds.
- **Confirm understanding before advancing** — when the user is wrong, don't reveal the answer immediately; explain why the choice missed and re-ask from a new angle.
- **Use polite speech (존댓말) when responding in Korean.**
- **Choice UI first** — all four decision points (mode selection, checkpoint, step transition, wrap-up) go through `AskUserQuestion`. Do not wait on a natural-language "next".

## Anti-patterns

- Asking checkpoint questions only in free text (weaker learning — MCQ structures thought).
- Embedding hints for the correct option ("(correct)", "(recommended)", …).
- Always placing the correct answer first.
- Advancing without waiting for the user's answer.
- In Deep dive mode, skipping the context load and falling back to generic explanations.
