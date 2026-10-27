# Estragon work status and session handoff

**Snapshot:** 2026-10-27, T06 completion PR based on `main` at `4f65a06` after merged [PR #23](https://github.com/resistdesign/Estragon/pull/23). T01–T05 are merged. T06 is **In review until approval and merge**. Independent text/buttons and primary-pointer input use ordinary GDScript; Gogo-generated wiring remains T07. Legacy and T04/T05 examples remain preserved.

**Milestone:** interactive Gogo/GDScript `Counter.gogo` compiled to GDScript, built from independent Estragon components, running and resizing in Godot 4.7. See [EXECUTION_PLAN.md](EXECUTION_PLAN.md).

**Start here:** inspect [T06 / issue #24](https://github.com/resistdesign/Estragon/issues/24) for its latest PR, CI and handoff. T07 follows only after T06 approval/merge. ARCHITECTURE documents text measurement, pointer/capture and lifecycle; TESTING contains the interactive example procedure. Automatic lifecycle remains required (ADR-0008).

## Current plan register

| ID | Status in this snapshot | Work | Live issue / relevant umbrella | Accepted completion evidence |
| --- | --- | --- | --- | --- |
| **T01** | **Done** | Godot 4.7 headless validation/CI | [#13](https://github.com/resistdesign/Estragon/issues/13), merged [PR #15](https://github.com/resistdesign/Estragon/pull/15) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40275222957); merge `0720948`. Manual visual check not run. |
| **T02** | **Done** | Independent display object/container foundations | [#16](https://github.com/resistdesign/Estragon/issues/16), merged [PR #17](https://github.com/resistdesign/Estragon/pull/17) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40276309421); merge `fb3aec6`. Lifecycle corrected by T03/ADR-0008. |
| **T03** | **Done** | Responsive stack layout, rectangles, surface and automatic lifecycle | [#18](https://github.com/resistdesign/Estragon/issues/18), merged [PR #19](https://github.com/resistdesign/Estragon/pull/19) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40282237018); merge `9df0626`. OpenGL captures inspected; interactive editor check not run. |
| **T04** | **Done** | Namespace-free markup → GDScript | [#20](https://github.com/resistdesign/Estragon/issues/20), merged [PR #21](https://github.com/resistdesign/Estragon/pull/21) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40284163867); merge `240e8bd`. OpenGL capture inspected. |
| **T05** | **Done** | GDScript-first hybrid Gogo, expressions and maps | [#22](https://github.com/resistdesign/Estragon/issues/22), merged [PR #23](https://github.com/resistdesign/Estragon/pull/23) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40448084799); merge `4f65a06`. Native graphics capture inspected; interactive editor check not run. |
| **T06** | **In review; Done only upon approval + merge** | Text/Button and primary-mouse input | [#24](https://github.com/resistdesign/Estragon/issues/24); umbrella [#3](https://github.com/resistdesign/Estragon/issues/3) | See live issue/PR for runtime/cleanup tests, native resized graphics capture and CI evidence. |
| T07 | Queued (T05, T06) | Generated event wiring and Counter | Create task issue on pickup | Pending |
| T08 | Queued (T07) | Editor build/run integration | [#6](https://github.com/resistdesign/Estragon/issues/6) (umbrella) | Pending |
| T09 | Queued (T07, R01 findings) | Observable properties and bindings | [#5](https://github.com/resistdesign/Estragon/issues/5) (umbrella) | Pending |
| T10 | Queued (T07, T08, parity) | Retire legacy JSON safely | Create task issue on pickup | Pending |
| **R01** | **Ready, parallel** | Ordinary `.gd` `@Bindable` feasibility | [#4](https://github.com/resistdesign/Estragon/issues/4) | Pending |
| R02 | Deferred | Renderer-backend research | [#2](https://github.com/resistdesign/Estragon/issues/2) | Pending |

**Statuses:** `Queued` = waiting on planned predecessor(s); `Ready` = actionable and unclaimed; `Active` = owned issue + branch with work underway; `Blocked` = evidence and decision/unblock step required; `In review` = PR open and awaiting approval/checks; `Done` = verified, approved and merged; `Deferred` = explicitly outside the current milestone. Never mark `Done` on an unmerged branch. A research task may complete with a well-evidenced negative feasibility finding.

**This file is a snapshot, not a live dashboard.** When an issue or PR disagrees with a snapshot row, **verify the linked live GitHub record and the merged code** before acting. Live issue and PR state holds temporary `Active`/`Blocked`/`In review` changes; update this file **in the PR that completes a task or intentionally revises the plan**, so merged `main` stays a useful starting point without a stream of conflicting status-only PRs. In a completion PR, `Done` is contingent on that PR actually merging; the PR/issue remains the live authority until then.

## Issue/PR ownership rule

- **One work ID per focused implementation PR.** A planning/ADR/process-only PR may be unassigned if it is explicitly labeled as such and includes no implementation work. The task issue is the durable conversation: scope, current owner/session or branch, plan/checklist, evidence, blockers, handoffs and linked PR.
- Existing issues #1–#6 were created for **broader architectural tracks** and may not describe the new per-PR scope. Treat rows labeled *umbrella* as related context, **not** as proof that a task-specific issue exists. On pickup, either explicitly adopt/update an issue for that one scoped task or create a narrow issue and link the umbrella; avoid duplicate work.
- Check existing issues, open PRs and branch names before claiming a task. If a task is already in progress, **resume the existing branch/PR and read its latest handoff**, rather than creating a second implementation.
- Parallel work uses separate issues and isolated branches/worktrees and documents shared interface decisions. No two agents edit the same worktree or silently change the same contract.

## Durable handoff template

Post a handoff comment on the **task issue or active PR** whenever a session ends with incomplete work, changes phase, encounters a blocker or needs another person/session. Do not rely on the Codex chat transcript: it may not be accessible next time. Keep the notes concise, verifiable and updated.

~~~markdown
### Handoff — <UTC date/time> — <work ID>

- **State:** Active / Blocked / In review / Ready
- **Task issue:** #...  **PR:** #... (or none)
- **Branch / commit:** <branch> / <SHA>; base: <main SHA or branch>
- **Completed since last handoff:** <specific checked steps and changed files>
- **Verification:** <exact commands / CI URLs / pass, fail or not run>
- **Remaining acceptance criteria:** <what is still actually unfinished>
- **Blockers / decisions needed:** <evidence, options, who must decide; or none>
- **Working tree / outstanding changes:** <clean, dirty paths, unpushed commits, or not accessible>
- **Next exact action:** <first command/file/review action, not “keep working”>
~~~

Also keep the **issue's checklist and PR description** accurate at meaningful milestones. If unable to update GitHub, preserve this handoff as a note committed to the task branch if possible, or report the missing durable handoff explicitly; **never claim cross-session continuity when the state only exists in ephemeral chat**.

## Resume checklist

1. Read `AGENTS.md`, this file, [EXECUTION_PLAN.md](EXECUTION_PLAN.md), design decisions and the task's exact acceptance criteria.
2. Fetch current `main`, inspect `git status --short --branch`, latest commits, open issues/PRs and the last task handoff. **Do not discard or overwrite uncommitted work.**
3. Reconcile the status snapshot against live issue/PR and code, confirm the next unfinished check, the assigned branch and its dependency state.
4. Resume that task on its existing branch if appropriate. If no active task exists, pick **one Ready task**, confirm/establish its issue, and record a short actionable plan there before editing code.
5. Work in small verified increments, post substantive progress, and leave the next handoff before ending the session.

A reviewer can ask “What is done, what is blocked, and what should Codex do next?” and answer it from **merged code + CI, the issue/PR timeline, and this snapshot**, without finding an old chat.
