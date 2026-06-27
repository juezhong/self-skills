---
name: commit-work-user
description: "Create high-quality git commits: review/stage intended changes, split into logical commits, and write clear commit messages (including Conventional Commits). Use when the user asks to commit, craft a commit message, stage changes, or split work into multiple commits."
---

# Commit work

## Goal
Make commits that are easy to review and safe to ship:
- only intended changes are included
- commits are logically scoped (split when needed)
- commit messages describe what changed and why
- All commit commands must include `-s` to ensure a Signed-off-by line is added.
- Use `git commit -s -m "..." -m "..."` (multi `-m`) for multi-line messages.
- Use `git commit -s -m "..."` (single `-m`) only when a single sentence is enough.

## Inputs to ask for (if missing)
- Single commit or multiple commits? (If unsure: default to multiple small commits when there are unrelated changes.)
- Commit style: Conventional Commits are required.
- Commit message language: Use Chinese.
- Commit format: Prioritize using multi-line commit messages, unless a single sentence clearly conveys the meaning.
- Any rules: max subject length, required scopes.

## Workflow (checklist)
1) Inspect the working tree before staging
   - `git status`
   - `git diff` (unstaged)
   - If many changes: `git diff --stat`
2) Decide commit boundaries (split if needed)
   - Split by: feature vs refactor, backend vs frontend, formatting vs logic, tests vs prod code, dependency bumps vs behavior changes.
   - If changes are mixed in one file, plan to use patch staging.
3) Stage only what belongs in the next commit
   - Prefer patch staging for mixed changes: `git add -p`
   - To unstage a hunk/file: `git restore --staged -p` or `git restore --staged <path>`
4) Review what will actually be committed
   - `git diff --cached`
   - Sanity checks:
     - no secrets or tokens
     - no accidental debug logging
     - no unrelated formatting churn
5) Describe the staged change in 1-2 sentences (before writing the message)
   - "What changed?" + "Why?"
   - If you cannot describe it cleanly, the commit is probably too big or mixed; go back to step 2.
6) Run the smallest relevant verification
   - Run the repo's fastest meaningful check (unit tests, lint, or build).
   - **IMPORTANT: Run BEFORE committing.** If it fails, fix before committing.
7) Write the commit message
   - Follow this template (Conventional Commits):
     ```
     <type>(<scope>): <summary>

     What:
     - <What changed.>

     Why:
     - <Why it changed.>

     Influence:
     - <Impact.>
     ```
   - Rules:
     - First line: `type(scope): summary` (Chinese summary OK, scope optional).
     - `What:` / `Why:` sections required. `Influence:` omit if none.
     - Body sections use `- ` bullets, not prose.
   - **Commit method (reliable — one command, no temp file):**
     ```
     git commit -s -m "<type>(<scope>): <summary>" -m "What:
     - <what changed>

     Why:
     - <why it changed>

     Influence:
     - <impact>"
     ```
     - First `-m` = subject line. Second `-m` = full body (What + Why + Influence).
     - **NEVER use heredoc piping** (e.g. `git commit <<'EOF'`). It is unreliable.
     - **NEVER use temp files** (e.g. `-F /tmp/msg.txt`). Multi `-m` is simpler and faster.
     - `git commit -s -m "..."` (single `-m`) is allowed only for truly trivial one-liners.
   - **VALIDATION** (internal, do NOT output to user):
     Before `git commit`, silently verify: line 1 has `type(scope): summary`,
     line 2 blank, What/Why bullets present. If fails → rewrite, do NOT commit.
8) Handle commit submission issues
   - If a GPG verification/signing failure occurs during commit submission, first provide the exact commit command to the user.
   - Do not add `--no-gpg-sign` by default.
   - Only bypass GPG signing if the user explicitly asks for it.
9) Repeat for the next commit until the working tree is clean

## Deliverable
Provide:
- the final commit message(s)
- a short summary per commit (what/why)
- the commands used to stage/review (at minimum: `git diff --cached`, plus any tests run)
