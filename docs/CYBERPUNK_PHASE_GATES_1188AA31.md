# OpenClaw HQ — Lofi Cyberpunk Overhaul
## Phase Gates Freeze + Acceptance Checklist + Dependency Map

- **Task ID:** 1188AA31-49E0-411F-A7B6-51410D528C3C
- **Project:** OpenClaw HQ — Lofi Cyberpunk Overhaul
- **Status:** **FROZEN EXECUTION GATES (v1)**
- **Baseline inputs:** `CYBERPUNK_PLAN.md`, `CYBERPUNK_EXECUTION_TASKS.md`, `CYBERPUNK_QA_REPORT.md`

---

## 1) Gate Policy (Strict)

1. **Serial enforcement:** No phase starts until prior phase gate is marked PASS.
2. **Evidence-first:** Every PASS requires linked evidence artifact(s) in `docs/`.
3. **No partial pass:** Any unmet blocker criterion = FAIL.
4. **Scope lock:** Logic/transport/persistence changes are out-of-scope and fail gate unless explicitly approved as a new task.
5. **Deferral discipline:** Non-blocking issues must be logged in a deferred list before gate closure.

---

## 2) Frozen Phase Gate Checklist

## Gate 0 — Baseline Lock (Entry Gate)
**Owner:** Scope  
**Purpose:** Freeze scope and prevent drift before implementation continues.

### Pass criteria (all required)
- [ ] Scope statement fixed to visual/UX overhaul only.
- [ ] Phase sequence fixed: P1 Primitives → P2 Screens → P3 Accessibility → P4 Release.
- [ ] Existing known blocker from QA report (Accessibility/Multi-resolution) explicitly carried forward.
- [ ] This gate document published in `docs/` and referenced by execution team.

### Evidence required
- [ ] Link to this doc
- [ ] Link to current QA report with blocker callouts

### Gate decision
- **Status:** PASS / FAIL
- **Decision note:** _TBD_

---

## Gate 1 — Shared Primitive System Complete (P1)
**Owners:** Atlas → Matrix → Prism → Scope

### Blocker criteria (all required)
- [ ] Atlas spec exists for `HQPanel`, `HQBadge`, `HQButton` with explicit variants/states (default, hover, active, disabled, focus).
- [ ] Token references are explicit per state (no ambiguous style language).
- [ ] Accessibility constraints defined per component state (contrast + focus + reduced-motion behavior).
- [ ] Matrix implementation compiles and primitives are used in at least 3 surfaces each (where applicable).
- [ ] No logic handler behavior changed in migrated surfaces.
- [ ] Prism verifies component state rendering + navigation/common action smoke.
- [ ] Prism confirms no auth/network/command/config boundary changes.

### Evidence required
- [ ] Atlas primitive spec artifact (`docs/...`)
- [ ] Matrix migration diff summary + `swift build` output
- [ ] Prism gate report for P1

### Exit artifact
- [ ] `P1_GATE_RESULT.md` (PASS/FAIL + defects)

### Gate decision
- **Status:** PASS / FAIL
- **Decision note:** _TBD_

---

## Gate 2 — Screen Migration Sequence Complete (P2)
**Owners:** Atlas → Matrix → Prism → Scope

### Ordered screen chain (hard dependency)
1. Agents
2. Tasks
3. Usage
4. Activity
5. Settings

### Blocker criteria per screen (all required before next screen)
- [ ] Screen migrated to primitive/token system (or documented approved exception).
- [ ] Empty/loading/error states present and stylistically consistent.
- [ ] Core workflows on that screen behaviorally unchanged.
- [ ] Prism issues per-screen gate decision (PASS/FAIL).
- [ ] Keyboard navigation/focus visibility validated on key controls.

### Global P2 pass criteria (all required)
- [ ] Five per-screen gate reports exist.
- [ ] No unresolved P0/P1 defects from any screen gate.

### Evidence required
- [ ] `P2_AGENTS_GATE.md`
- [ ] `P2_TASKS_GATE.md`
- [ ] `P2_USAGE_GATE.md`
- [ ] `P2_ACTIVITY_GATE.md`
- [ ] `P2_SETTINGS_GATE.md`

### Gate decision
- **Status:** PASS / FAIL
- **Decision note:** _TBD_

---

## Gate 3 — Accessibility Hardening Complete (P3)
**Owners:** Atlas → Matrix → Prism → Scope

### Blocker criteria (all required)
- [ ] Reduced-motion policy finalized at component and screen level.
- [ ] Reduced-motion toggle implemented and functional across targeted animated surfaces.
- [ ] Contrast target matrix defined for critical text/background/status states.
- [ ] Contrast fixes applied without style divergence.
- [ ] Prism validates reduced-motion behavior end-to-end.
- [ ] Prism confirms contrast audit passes on critical states.

### Carry-forward blocker closure from prior QA report
- [ ] Multi-resolution validation executed for compact/default/wide across all tabs.
- [ ] Accessibility evidence consolidated into a final P3 report.

### Evidence required
- [ ] A11y spec + contrast matrix artifact
- [ ] Implementation note for reduced-motion toggle/plumbing
- [ ] Prism accessibility + multi-resolution verification report

### Exit artifact
- [ ] `P3_GATE_RESULT.md` (must include explicit closure of previous Gate 4 fail reasons)

### Gate decision
- **Status:** PASS / FAIL
- **Decision note:** _TBD_

---

## Gate 4 — Release Validation + Ship Recommendation (P4)
**Owners:** Matrix → Prism → Scope

### Blocker criteria (all required)
- [ ] `swift build` passes.
- [ ] `bash build-app.sh` passes.
- [ ] App launch + tab navigation smoke passes (Chat, Agents, Tasks, Usage, Activity, Settings).
- [ ] Security boundary revalidated: visual/UX-only changes; no credential/auth/command path regressions.
- [ ] No unresolved P0/P1 defects.

### Evidence required
- [ ] Build logs + artifact location
- [ ] Final Prism report with explicit ship/no-ship recommendation
- [ ] Scope closure note listing deferred items and next queue

### Gate decision
- **Status:** PASS / FAIL
- **Decision note:** _TBD_

---

## 3) Dependency Map (Frozen)

```text
Gate 0 (Baseline Lock)
   ↓
Gate 1 (Primitives)
   ↓
Gate 2.1 Agents
   ↓
Gate 2.2 Tasks
   ↓
Gate 2.3 Usage
   ↓
Gate 2.4 Activity
   ↓
Gate 2.5 Settings
   ↓
Gate 3 (Accessibility + Multi-resolution closure)
   ↓
Gate 4 (Release validation + ship recommendation)
```

## Dependency rules
- **Hard stop:** Any FAIL blocks all downstream gates.
- **No leapfrogging:** P3 cannot begin before all five P2 screen gates PASS.
- **No silent deferrals:** Any deferred item must be documented with owner and target phase.

---

## 4) Execution Log Template (Use for each gate)

```md
## Gate X — <Name>
- Date:
- Owners:
- Inputs reviewed:
- Criteria results:
  - [ ] Criterion A
  - [ ] Criterion B
- Defects:
  - ID / severity / owner / ETA
- Decision: PASS | FAIL
- Approved by:
```

---

## 5) Immediate Next Action
- Start/continue at **Gate 1** and do not open P2 migration work until `P1_GATE_RESULT.md` is PASS with evidence links.
