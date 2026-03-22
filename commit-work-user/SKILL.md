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
- Prefer `git commit -s -v` for normal commits, especially when using a multi-line commit message.
- Use `git commit -s -m "..."` only when a single sentence is enough to explain the change clearly.

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
6) Write the commit message
   - Use `references/commit-message-template.md` always.
   - Use Conventional Commits (required):
     - `type(scope): short summary`
     - blank line
     - body (what/why, not implementation diary)
     - footer (BREAKING CHANGE) if needed
   - Prefer an editor for multi-line messages: `git commit -v`
   - The short summary should cover all files included in this commit.
7) Handle commit submission issues
   - If a GPG verification/signing failure occurs during commit submission, first provide the exact commit command to the user.
   - Do not add `--no-gpg-sign` by default.
   - Only bypass GPG signing if the user explicitly asks for it.
8) Run the smallest relevant verification
   - Run the repo's fastest meaningful check (unit tests, lint, or build) before moving on.
9) Repeat for the next commit until the working tree is clean

## Deliverable
Provide:
- the final commit message(s)
- a short summary per commit (what/why)
- the commands used to stage/review (at minimum: `git diff --cached`, plus any tests run)
