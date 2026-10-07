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
- All suggested or executed commit commands must include `-S -s`: `-S` requests GPG signing and `-s` adds a Signed-off-by line.
- Default behavior: prepare commit message file(s) and tell the user how to commit them. Do not run `git commit` unless the user explicitly asks the agent to make the commit.
- Save message files under `./commit-message/YYYY-MM-DD/` in the current working directory. For multiple commits, save one file per commit.
- A first-time message uses `<slug>.txt` with no version suffix. Add `-v1`, `-v2`, etc. only when the user asks to revise that same commit message; preserve the earlier file and save each revision as a new version. Different commits get distinct descriptive slugs and do not get version suffixes just because they share a date. Use `.txt` extension.

## Inputs to ask for (if missing)
- Single commit or multiple commits? (If unsure: default to multiple small commits when there are unrelated changes.)
- Commit style: Conventional Commits are required.
- Commit message language: Use Chinese.
- Commit format: Prioritize using multi-line commit messages, unless a single sentence clearly conveys the meaning.
- Any rules: max subject length, required scopes.

## Workflow (checklist)
1) Inspect the working tree and repository root before staging
   - `git status`
   - `git diff` (unstaged)
   - If many changes: `git diff --stat`
   - Confirm the current directory where the message files will be saved; use `./commit-message/` relative to the current working directory, not the repository root unless it is also the current directory.
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
6) Run verification only when the user asks for tests or verification, or the task itself requires it. Do not add or run tests by default.
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
   - Write the complete message (subject and body) into a UTF-8 `.txt` file at `./commit-message/YYYY-MM-DD/<slug>-vN.txt`.
   - `YYYY-MM-DD` is the local current date. `<slug>` is a short filesystem-safe identifier derived from the subject; use lowercase ASCII with hyphens where practical.
   - Check for existing files before writing. For a new commit message, choose an unused descriptive slug and omit a version suffix. When revising a previously saved message at the user's request, keep its slug, preserve the existing file, and append the next version suffix (`-v1`, then `-v2`, etc.). Do not overwrite existing files.
   - Keep the message format in the file exactly as intended for the commit, including blank lines and any `What`, `Why`, and optional `Influence` sections.
   - Validate the saved file: subject follows Conventional Commits, blank line after subject, and required `What` / `Why` bullets are present.
8) Give the user the exact commit command for each message file
   - Show the path and a command using the staged changes and the saved message file, for example:
     ```sh
     git commit -S -s -F "./commit-message/YYYY-MM-DD/<slug>-v1.txt"
     ```
   - If there are multiple logical commits, explain that the user must stage the corresponding changes before running each command.
   - `-S` signs the commit and `-s` adds the Signed-off-by trailer. Do not add `--no-gpg-sign` unless explicitly requested.
9) Only if the user explicitly asked the agent to commit: execute the matching `git commit -S -s -F <message-file>` command after reviewing the staged diff. Otherwise, stop after saving the file(s) and providing the command(s).

## Deliverable
Provide:
- the final commit message(s)
- the saved message file path(s)
- a short summary per commit (what/why)
- the exact suggested `git commit -S -s -F ...` command(s)
- the staging/review commands used (at minimum: `git diff --cached` when changes are staged)
