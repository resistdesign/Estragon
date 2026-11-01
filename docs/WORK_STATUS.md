# Estragon work status and session handoff

**Snapshot:** 2026-11-01. T01–T08 and native planning PR #31 are merged. N01 is merged in PR #32 (`efaad96`). N02 is merged in PR #34 (`8a864a2`). N03 is merged in PR #36 (`a87c33b`). R01 research PR #38 is merged; its negative native `.gd` annotation result is documented. The owner **has made the authoring decision**: lowercase `@bindable` in authored Gogo only (ADR-0013). T09 will cover bindable model objects, reactive layout and observable collections, not just UI text. Normal addon editing/Play uses only Godot; TypeScript/Bun is optional reference tooling. **Owner amendment:** ADR-0014 requires Godot 4.0+; until C01 is verified, shipped compatibility is not certified by the 4.7 suite.

**Milestone:** interactive Gogo/GDScript `Counter.gogo` compiled to GDScript, built from independent Estragon components, running and resizing in Godot 4.7. See [EXECUTION_PLAN.md](EXECUTION_PLAN.md).

**Start here:** C01-F #49 / PR #62 merged at `95efa45`. C01-G #50 is
in review in unmerged PR #63 on `codex/c01-g-unsaved-play`, based on latest main
`393e91c`. Read the live issue/PR and [C01-G evidence](C01_G_PLAY.md) before
resuming. C01-H #51, #44 disposition and T09 remain queued. The owner testing
policy requires automated real-editor Play, not physical keyboard checks.

## Current plan register

| ID | Status in this snapshot | Work | Live issue / relevant umbrella | Accepted completion evidence |
| --- | --- | --- | --- | --- |
| **T01** | **Done** | Godot 4.7 headless validation/CI | [#13](https://github.com/resistdesign/Estragon/issues/13), merged [PR #15](https://github.com/resistdesign/Estragon/pull/15) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40275222957); merge `0720948`. Manual visual check not run. |
| **T02** | **Done** | Independent display object/container foundations | [#16](https://github.com/resistdesign/Estragon/issues/16), merged [PR #17](https://github.com/resistdesign/Estragon/pull/17) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40276309421); merge `fb3aec6`. Lifecycle corrected by T03/ADR-0008. |
| **T03** | **Done** | Responsive stack layout, rectangles, surface and automatic lifecycle | [#18](https://github.com/resistdesign/Estragon/issues/18), merged [PR #19](https://github.com/resistdesign/Estragon/pull/19) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40282237018); merge `9df0626`. OpenGL captures inspected; interactive editor check not run. |
| **T04** | **Done** | Namespace-free markup → GDScript | [#20](https://github.com/resistdesign/Estragon/issues/20), merged [PR #21](https://github.com/resistdesign/Estragon/pull/21) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40284163867); merge `240e8bd`. OpenGL capture inspected. |
| **T05** | **Done** | GDScript-first hybrid Gogo, expressions and maps | [#22](https://github.com/resistdesign/Estragon/issues/22), merged [PR #23](https://github.com/resistdesign/Estragon/pull/23) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40448084799); merge `4f65a06`. Native graphics capture inspected; interactive editor check not run. |
| **T06** | **Done** | Text/Button and primary-mouse input | [#24](https://github.com/resistdesign/Estragon/issues/24), merged [PR #25](https://github.com/resistdesign/Estragon/pull/25); umbrella [#3](https://github.com/resistdesign/Estragon/issues/3) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40451329471); merge `1a7cc2e`. Native resized graphics inspected; physical/editor smoke not run. |
| **T07** | **Done** | Generated Button.pressed wiring and Counter.gogo | [#26](https://github.com/resistdesign/Estragon/issues/26), merged [PR #27](https://github.com/resistdesign/Estragon/pull/27) | [Green CI](https://github.com/resistdesign/Estragon/actions/runs/40618408960); merge `0a1cfc1`. Native Counter graphics inspected. |
| **T08** | **Done** | Native highlighting, saved-source builds and F5/F6 gate | [#28](https://github.com/resistdesign/Estragon/issues/28); umbrella [#6](https://github.com/resistdesign/Estragon/issues/6) | Merged [PR #29](https://github.com/resistdesign/Estragon/pull/29), `53809cf`; isolated editor/Play evidence in #28/#29; owner manually verified font-size edit and Play. |
| **N01** | **Done (merged PR #32)** | Native Gogo lexer/parser/typed frontend | [#30](https://github.com/resistdesign/Estragon/issues/30) | Godot-only no-Bun proof: 103 reference cases, 558 assertions; full Bun/runtime/editor suites pass. Exact CI and handoff in issue/PR. |
| **N02** | **Done (merged PR #34)** | Native codegen, source maps and T04–T07 parity | [#33](https://github.com/resistdesign/Estragon/issues/33) | Godot-only generation, direct Counter and shared runtime/negative tests; exact CI/evidence/handoff in issue/PR. |
| **N03** | **Done (merged PR #36)** | Native editor builds, both Play gates, resources and restart without tools | [#35](https://github.com/resistdesign/Estragon/issues/35) | Fresh self-contained editor/game with empty PATH; native transactions/cache/class identity and Play failure/recovery. Exact checks/CI/handoff in issue/PR. |
| T09-A…D | Queued (C01 blocking compatibility fixes) | Gogo-only `@bindable` models → component/layout bindings + Box hierarchy → observable collections/repeaters → two-way and hardening | [#5](https://github.com/resistdesign/Estragon/issues/5) (umbrella), [REACTIVITY_PLAN](REACTIVITY_PLAN.md) | Owner decision accepted; no T09 implementation merged |
| T10 | Ready (verify legacy parity on pickup) | Retire legacy JSON safely | Create task issue on pickup | Pending |
| **R01** | **Done (merged PR #38)** | Historical ordinary `.gd` annotation feasibility (old requirement superseded by ADR-0013) | [#4](https://github.com/resistdesign/Estragon/issues/4), [PR #38](https://github.com/resistdesign/Estragon/pull/38) | [Evidence](BINDABLE_FEASIBILITY.md), isolated Godot-only runtime/editor probes; green CI. Gogo-only `@bindable` is the accepted future path, not implemented here. |
| **E01** | **Done (narrow merged fix); remaining acceptance tracked separately** | Normal automatic highlighting; filtered identity remains #44 | [#37](https://github.com/resistdesign/Estragon/issues/37), merged [PR #40](https://github.com/resistdesign/Estragon/pull/40) | [E01 evidence](E01_COMPATIBILITY.md), merge `41b43b4`; no universal full-addon support claim. |
| **C01** | **Required release gate; incomplete** | Godot 4.0+ native editor/compiler/runtime support | [#41](https://github.com/resistdesign/Estragon/issues/41) | [Measured baseline](C01_COMPATIBILITY.md); red older-engine stages remain. |
| **C01-A** | **Done (merged PR #52)** | Selectable official-engine matrix, source inventory and prioritized issues | [#42](https://github.com/resistdesign/Estragon/issues/42) | 4.0–4.7 actual engine evidence, latest 4.7.2 plus 4.7.0 pin, collector failure tests and informational CI; merge `46bc752`, exact final CI/handoff in #42/#52. |
| **C01-B** | **Done (scoped fix merged PR #53)** | Scalar component maxima, button label clamp and 4.0 incoming-signal key parsing | [#45](https://github.com/resistdesign/Estragon/issues/45) | [Runtime evidence](C01_B_RUNTIME.md); merge `29fc202`, individual scoped stages are required by CI. Historical cold Text-first failures are retained in that snapshot; C01-E restores those scoped gates. |
| **C01-C** | **Done (merged PR #57)** | Version-gated proactive arity checks; preserve valid callbacks and lifecycle | [#46](https://github.com/resistdesign/Estragon/issues/46) | [Nine-engine evidence](C01_C_CALLBACKS.md): Counter/signals/guard probes pass on 4.0–4.7.2; owner-approved diagnostic timing. Required CI passes; merged `68f1ec4`. |
| **C01-D** | **Done (merged PR #59)** | Canonical numeric tokens and native-value preservation | [#47](https://github.com/resistdesign/Estragon/issues/47) | [Nine-engine evidence](C01_D_NUMBERS.md): numeric/native-preservation and C01-B/C gates pass; native conversion limits stay explicit. Required CI and native graphics pass. |
| **C01-E** | **Done (merged PR #60, `c17902a`)** | Native semantic validation, resource paths and script identity | [#48](https://github.com/resistdesign/Estragon/issues/48) | [Nine-engine evidence](C01_E_VALIDATION.md): native semantics, Counter, registered/cached identity, transactional rollback/recovery and cold runtime gates PASS; owner-approved preflight availability differs by engine. Other editor/grammar limits remain explicit. |
| **C01-F** | **Done (merged PR #62, `95efa45`)** | Native editor startup and plugin lifecycle | [#49](https://github.com/resistdesign/Estragon/issues/49) | [Nine-engine lifecycle evidence](C01_F_EDITOR.md): 36/36 required stages PASS, clean editor startup/refresh/restart, real saved-source builds. Older unsaved Play remains C01-G. |
| **C01-G** | **In review (PR #63; unmerged)** | Unsaved/unsavable Gogo F5/F6 fail-closed Play and recovery | [#50](https://github.com/resistdesign/Estragon/issues/50) | [Play evidence](C01_G_PLAY.md); 18/18 Play phases, 864 native assertions and 36/36 lifecycle stages PASS; final CI/handoff in #50/#63. |
| C01-H | Queued after C01-G and E01-F disposition | Distribution, cross-version release gate | [#51](https://github.com/resistdesign/Estragon/issues/51), [#44](https://github.com/resistdesign/Estragon/issues/44) | Release evidence and remaining unrelated gaps to be handled separately; physical/manual keypress tests are not required per AGENTS.md. |
| R02 | Deferred | Renderer-backend research | [#2](https://github.com/resistdesign/Estragon/issues/2) | Pending |

**Statuses:** `Queued` = waiting on planned predecessor(s); `Ready` = actionable and unclaimed; `Active` = owned issue + branch with work underway; `Blocked` = evidence and decision/unblock step required; `In review` = PR open and awaiting approval/checks; `Done` = verified, approved and merged; `Deferred` = explicitly outside the current milestone. Never mark `Done` on an unmerged branch. A research task may complete with a well-evidenced negative feasibility finding.

**This file is a snapshot, not a live dashboard.** When an issue or PR disagrees with a snapshot row, **verify the linked live GitHub record and the merged code** before acting. Live issue and PR state holds temporary `Active`/`Blocked`/`In review` changes; update this file **in the PR that completes a task or intentionally revises the plan**, so merged `main` stays a useful starting point without a stream of conflicting status-only PRs. In a completion PR, `Done` is contingent on that PR actually merging; the PR/issue remains the live authority until then.

## Issue/PR ownership rule

- **Maximum one open PR total across the repository**, including draft, docs,
  research and agent PRs. Check all open PRs, resume the current branch/PR, and
  finish or close it before opening the next. No stacked or replacement PRs.
- Future work belongs in issues while the current PR is active. A blocked PR
  needs documented evidence and an owner decision, not another PR. No automatic
  merges. Every task has a durable issue, checkpoints, verification and handoff.
- Queue: C01-F #49/#62 merged → **C01-G #50/#63 active** → E01-F #44 disposition → C01-H #51 → T09-A #43 →
  T09-B/C/D #5. #40 merged. Check live issues before advancing.

- **One work ID per focused implementation PR.** A planning/ADR/process-only PR may be unassigned if it is explicitly labeled as such and includes no implementation work. The task issue is the durable conversation: scope, current owner/session or branch, plan/checklist, evidence, blockers, handoffs and linked PR.
- Existing issues #1–#6 were created for **broader architectural tracks** and may not describe the new per-PR scope. Treat rows labeled *umbrella* as related context, **not** as proof that a task-specific issue exists. On pickup, either explicitly adopt/update an issue for that one scoped task or create a narrow issue and link the umbrella; avoid duplicate work.
- Check existing issues, open PRs and branch names before claiming a task. If a task is already in progress, **resume the existing branch/PR and read its latest handoff**, rather than creating a second implementation.
- Issue-only research/backlog maintenance may proceed while the single PR is active. Do not start competing implementation or bypass a blocked PR.

## Durable handoff template

Post a handoff comment on the **task issue or active PR** whenever a session ends with incomplete work, changes phase, encounters a blocker or needs another person/session. Do not rely on the Codex chat transcript: it may not be accessible next time. Keep the notes concise, verifiable and updated.

~~~markdown
### Handoff — <UTC date/time> — <work ID>

- **State:** Active / Blocked / In review / Ready
- **Task issue:** #...  **PR:** #... (or none); repository open-PR count: ... (maximum one)
- **Branch / commit:** <branch> / <SHA>; base: <main SHA or branch>
- **Completed since last handoff:** <specific checked steps and changed files>
- **Verification:** <exact commands / CI URLs / pass, fail or not run>
- **Remaining acceptance criteria:** <what is still actually unfinished>
- **Preserved local work / stashes:** <named stash and reason; never overwrite unfinished work>
- **Blockers / owner decision / queue:** <evidence, options, who must decide; or none>
- **Working tree / outstanding changes:** <clean, dirty paths, unpushed commits, or not accessible>
- **Next exact action:** <first command/file/review action, not “keep working”>
~~~

Also keep the **issue's checklist and PR description** accurate at meaningful milestones. If unable to update GitHub, preserve this handoff as a note committed to the task branch if possible, or report the missing durable handoff explicitly; **never claim cross-session continuity when the state only exists in ephemeral chat**.

## Resume checklist

1. Read `AGENTS.md`, this file, [EXECUTION_PLAN.md](EXECUTION_PLAN.md), design decisions and the task's exact acceptance criteria.
2. Check the repository-wide open-PR list (maximum one); resume it rather than create a replacement. Fetch current `main`, inspect `git status --short --branch`, latest commits, open issues/PRs and the last task handoff. **Apply AGENTS.md’s standing cleanup authorization to disposable Godot artifacts; preserve unfinished implementation work.**
3. Reconcile the status snapshot against live issue/PR and code, confirm the next unfinished check, the assigned branch and its dependency state.
4. Resume that task on its existing branch if appropriate. If no active task exists, pick **one Ready task**, confirm/establish its issue, and record a short actionable plan there before editing code.
5. Work in small verified increments, post substantive progress, and leave the next handoff before ending the session.

A reviewer can ask “What is done, what is blocked, and what should Codex do next?” and answer it from **merged code + CI, the issue/PR timeline, and this snapshot**, without finding an old chat.
