# Estragon work status and session handoff

**Snapshot:** 2026-10-29. T01–T08 and native planning PR #31 are merged. N01 is merged in PR #32 (`efaad96`). N02 is merged in PR #34 (`8a864a2`). N03 is merged in PR #36 (`a87c33b`). R01 research PR #38 is merged; its negative native `.gd` annotation result is documented. The owner **has made the authoring decision**: lowercase `@bindable` in authored Gogo only (ADR-0013). T09 will cover bindable model objects, reactive layout and observable collections, not just UI text. Normal addon editing/Play uses only Godot; TypeScript/Bun is optional reference tooling. **Owner amendment:** ADR-0014 requires Godot 4.0+; until C01 is verified, shipped compatibility is not certified by the 4.7 suite.

**Milestone:** interactive Gogo/GDScript `Counter.gogo` compiled to GDScript, built from independent Estragon components, running and resizing in Godot 4.7. See [EXECUTION_PLAN.md](EXECUTION_PLAN.md).

**Start here:** Godot **4.0+ is now a non-negotiable compatibility baseline**; [C01 #41](https://github.com/resistdesign/Estragon/issues/41) records the cross-version audit and incomplete proof. R01 [PR #38](https://github.com/resistdesign/Estragon/pull/38) has merged. E01 [PR #40](https://github.com/resistdesign/Estragon/pull/40) has green 4.7 editor CI but remains in review, with a **4.0+ compatibility concern**. T09's accepted Gogo-only source contract is in [ADR-0013](DECISIONS.md), [T09 issue #5](https://github.com/resistdesign/Estragon/issues/5) and [REACTIVITY_PLAN](REACTIVITY_PLAN.md); its implementation must target 4.0 too. Documentation PR #39 is merged; ADR-0013/0014 and the staged reactivity plan are preserved. PR #40 is the sole open PR. After it merges or closes, pick up C01-A #42; T09-A #43 follows the blocking compatibility fixes. GitHub is the live source of truth.

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
| T09-A…D | Queued (E01 closure, C01 audit and blocking fixes) | Gogo-only `@bindable` models → component/layout bindings + Box hierarchy → observable collections/repeaters → two-way and hardening | [#5](https://github.com/resistdesign/Estragon/issues/5) (umbrella), [REACTIVITY_PLAN](REACTIVITY_PLAN.md) | Owner decision accepted; no T09 implementation merged |
| T10 | Ready (verify legacy parity on pickup) | Retire legacy JSON safely | Create task issue on pickup | Pending |
| **R01** | **Done (merged PR #38)** | Historical ordinary `.gd` annotation feasibility (old requirement superseded by ADR-0013) | [#4](https://github.com/resistdesign/Estragon/issues/4), [PR #38](https://github.com/resistdesign/Estragon/pull/38) | [Evidence](BINDABLE_FEASIBILITY.md), isolated Godot-only runtime/editor probes; green CI. Gogo-only `@bindable` is the accepted future path, not implemented here. |
| **E01** | **In review; owner decision on blocked end-to-end acceptance** | Automatically choose Gogo highlighting for new/restored/already-open tabs | [#37](https://github.com/resistdesign/Estragon/issues/37), [PR #40](https://github.com/resistdesign/Estragon/pull/40) | [E01 evidence](E01_COMPATIBILITY.md): isolated 4.0–4.7 normal/restart checks; hidden unassociated filtered tab unmet; complete addon startup fails on 4.0–4.6. 4.7 full suite green. Owner decision required; not merged. |
| **C01** | **Queued; mandatory release gate** | Godot 4.0+ audit and multi-version native editor/compiler/runtime support | [#41](https://github.com/resistdesign/Estragon/issues/41) | Current tests target 4.7; 4.0 APIs lack several methods currently called, so 4.0+ not yet certified. |
| **C01-A** | **Queued until #40 merges/closes** | Compatibility inventory, real engine matrix and prioritized follow-ups | [#42](https://github.com/resistdesign/Estragon/issues/42) | Next task; no implementation started in E01. |
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
- Queue: #40 → C01-A #42 → focused C01-B/C fixes in measured dependency order →
  T09-A #43 → T09-B/C/D #5. Check live issues before advancing.

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
