# Complete Development Workflow

> **Purpose:** This is the repeatable process for the team. Follow this EXACT flow for all development work.

---

## The Master Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPMENT WORKFLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

                              SESSION START
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │      /orient        │
                        │─────────────────────│
                        │ • Reads WORKING-*.md│
                        │ • Reads PROGRESS.md │
                        │ • Reads features.json│
                        │ • Runs lint + tests │
                        │ • BLOCKS if unhealthy│
                        └──────────┬──────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │    WHAT ARE YOU DOING?       │
                    └──────────────────────────────┘
                                   │
       ┌───────────┬───────────┬───┴───┬───────────┬───────────┐
       ▼           ▼           ▼       ▼           ▼           │
   ┌───────┐  ┌───────┐  ┌─────────┐ ┌────────┐ ┌─────────┐   │
   │ NEW   │  │ BUG   │  │CONTINUE │ │REFACTOR│ │ EXPLORE │   │
   │FEATURE│  │ FIX   │  │  WORK   │ │        │ │         │   │
   └───┬───┘  └───┬───┘  └────┬────┘ └───┬────┘ └────┬────┘   │
       │          │           │          │           │         │
       ▼          ▼           ▼          ▼           │         │
  ┌─────────────────────────────────────────────────┐│         │
  │           IMPLEMENTATION PHASES                 ││         │
  │    (See detailed flow below for each type)      ││         │
  └─────────────────────────────────────────────────┘│         │
       │          │           │          │           │         │
       └──────────┴───────────┴──────────┴───────────┘         │
                              │                                 │
                              ▼                                 │
                    ┌─────────────────────┐                    │
                    │    SESSION END      │◄───────────────────┘
                    │─────────────────────│     (Explore doesn't
                    │    /handoff         │      need commit)
                    │ Saves context for   │
                    │ next session        │
                    └─────────────────────┘
```

---

## Workflow by Type

### 🆕 NEW FEATURE

**When:** Building something that doesn't exist yet.

```
PHASE 1: UNDERSTAND
├── Skill: superpowers:brainstorming (if requirements unclear)
├── Ask: "Do I fully understand what's being asked?"
└── Output: Clear requirements

PHASE 2: PLAN
├── Skill: superpowers:write-plan (if 3+ files)
├── Skill: feature-tracker (add features with status: pending)
└── Output: Implementation plan, features.json updated

PHASE 3: IMPLEMENT (repeat for each task)
├── Skill: superpowers:test-driven-development
├── Steps:
│   1. Write failing test
│   2. Run test → MUST FAIL
│   3. Write minimal code to pass
│   4. Run test → MUST PASS
│   5. Refactor if needed
└── Output: Working code with tests

PHASE 4: SIMPLIFY
├── Skill: code-simplifier
├── Remove over-engineering
├── Delete "just in case" code
└── Output: Clean, minimal code

PHASE 5: VERIFY
├── Skill: lint-before-commit
├── Skill: superpowers:verification-before-completion
├── Run linter → exit code 0
├── Run tests → all pass
└── Output: Evidence of passing

PHASE 6: COMMIT & LOG
├── git commit (small, focused)
├── Skill: progress-logger → PROGRESS.md
├── Skill: feature-tracker → mark complete
└── Output: Committed code, logged progress
```

**Skills Used:**
| Phase | Skill | Required? |
|-------|-------|-----------|
| Understand | `superpowers:brainstorming` | If unclear |
| Plan | `superpowers:write-plan` | If complex |
| Plan | `feature-tracker` | Always |
| Implement | `superpowers:test-driven-development` | Always |
| Simplify | `code-simplifier` | Always |
| Verify | `lint-before-commit` | Always |
| Verify | `superpowers:verification-before-completion` | Always |
| Commit | `progress-logger` | Always |

---

### 🐛 BUG FIX

**When:** Something is broken and needs to be fixed.

```
PHASE 1: UNDERSTAND
├── Skill: superpowers:systematic-debugging
├── Reproduce the bug
├── Find root cause (not symptoms)
└── Output: Clear understanding of what's wrong

PHASE 2: PLAN
├── Usually skip (bugs rarely need plans)
├── Exception: Complex multi-file bugs
└── Output: Mental model of fix

PHASE 3: IMPLEMENT
├── Skill: superpowers:test-driven-development
├── Steps:
│   1. Write test that REPRODUCES the bug
│   2. Run test → MUST FAIL (proves bug exists)
│   3. Fix the bug (minimal change)
│   4. Run test → MUST PASS (proves fix works)
│   5. Run ALL tests (no regressions)
└── Output: Fix with regression test

PHASE 4: SIMPLIFY
├── Usually minimal for bug fixes
├── Don't refactor unrelated code
└── Output: Clean fix only

PHASE 5: VERIFY
├── Skill: lint-before-commit
├── Run linter → exit code 0
├── Run tests → all pass (including new test)
└── Output: Evidence of passing

PHASE 6: COMMIT & LOG
├── git commit -m "fix: description"
├── Skill: progress-logger → PROGRESS.md
├── Skill: learnings-logger (if bug was tricky)
└── Output: Committed fix, documented gotcha
```

**Skills Used:**
| Phase | Skill | Required? |
|-------|-------|-----------|
| Understand | `superpowers:systematic-debugging` | Always |
| Implement | `superpowers:test-driven-development` | Always |
| Verify | `lint-before-commit` | Always |
| Commit | `progress-logger` | Always |
| Commit | `learnings-logger` | If tricky |

---

### ▶️ CONTINUE WORK

**When:** Picking up where you left off from a previous session.

```
PHASE 0: ORIENT (already done)
├── /orient already read WORKING-*.md
├── features.json shows current in_progress
└── PROGRESS.md shows last commit

PHASE 1: UNDERSTAND
├── Review last session's context
├── Check: What's the next TODO item?
└── Output: Clear next step

PHASE 2: PLAN
├── Usually skip (plan exists from before)
├── Exception: Plan needs updating
└── Output: Continue with existing plan

PHASE 3-6: Same as NEW FEATURE
└── Pick up TDD cycle where you left off
```

**Skills Used:**
| Phase | Skill | Required? |
|-------|-------|-----------|
| Orient | `/orient` command | Already done |
| Implement | `superpowers:test-driven-development` | Always |
| Verify | `lint-before-commit` | Always |
| Commit | `progress-logger` | Always |

---

### 🔧 REFACTOR

**When:** Improving code structure without changing behavior.

```
PHASE 1: UNDERSTAND
├── Skill: superpowers:brainstorming (if unclear goals)
├── Ask: "What problem does this refactor solve?"
├── CRITICAL: Define "done" upfront
└── Output: Clear refactor goal

PHASE 2: PLAN
├── Skill: superpowers:write-plan (usually needed)
├── Refactors often touch many files
└── Output: Step-by-step plan

PHASE 3: IMPLEMENT
├── Skill: superpowers:test-driven-development
├── CRITICAL: Tests MUST pass before AND after each step
├── Steps:
│   1. Run existing tests → MUST PASS
│   2. Make small structural change
│   3. Run tests → MUST STILL PASS
│   4. Repeat until done
└── Output: Refactored code, same behavior

PHASE 4: SIMPLIFY
├── Skill: code-simplifier
├── This IS the goal of refactoring
└── Output: Clean, simple code

PHASE 5: VERIFY
├── Skill: superpowers:code-reviewer
├── Behavior unchanged? Check tests.
├── Run linter → exit code 0
└── Output: Evidence of same behavior

PHASE 6: COMMIT & LOG
├── git commit -m "refactor: description"
├── Skill: progress-logger → PROGRESS.md
└── Output: Committed refactor
```

**Skills Used:**
| Phase | Skill | Required? |
|-------|-------|-----------|
| Understand | `superpowers:brainstorming` | If unclear |
| Plan | `superpowers:write-plan` | Usually |
| Implement | `superpowers:test-driven-development` | Always |
| Simplify | `code-simplifier` | Always |
| Verify | `superpowers:code-reviewer` | Recommended |
| Verify | `lint-before-commit` | Always |
| Commit | `progress-logger` | Always |

---

### 🔍 EXPLORE

**When:** Learning about the codebase, researching, or answering questions.

```
NO IMPLEMENTATION PHASES - This is READ-ONLY

EXPLORE WORKFLOW:
├── Search codebase (Glob, Grep, Read)
├── Use Task tool with subagent_type=Explore
├── Ask clarifying questions
├── Take notes if useful
└── NO commits (nothing changed)

IF EXPLORATION LEADS TO WORK:
├── Switch to appropriate workflow (NEW FEATURE, BUG FIX, etc.)
├── Skill: feature-tracker (add discovered work)
└── Start from Phase 1: Understand
```

**Skills Used:**
| Phase | Skill | Required? |
|-------|-------|-----------|
| Search | Task (Explore agent) | Recommended |
| Notes | `learnings-logger` | If gotcha found |

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SKILL QUICK REFERENCE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SESSION START                                                               │
│  └── /orient                    Read context, verify baseline healthy        │
│                                                                              │
│  UNDERSTAND (Phase 1)                                                        │
│  └── superpowers:brainstorming  Clarify unclear requirements                 │
│  └── superpowers:systematic-debugging  For bug fixes                         │
│                                                                              │
│  PLAN (Phase 2)                                                              │
│  └── superpowers:write-plan     Create detailed implementation plan          │
│  └── feature-tracker            Add features to features.json                │
│                                                                              │
│  IMPLEMENT (Phase 3)                                                         │
│  └── superpowers:test-driven-development  ALWAYS use for code changes        │
│                                                                              │
│  SIMPLIFY (Phase 4)                                                          │
│  └── code-simplifier            Remove over-engineering                      │
│                                                                              │
│  VERIFY (Phase 5)                                                            │
│  └── lint-before-commit         ALWAYS before any commit                     │
│  └── superpowers:verification-before-completion  Evidence before "done"      │
│  └── superpowers:code-reviewer  Review against plan (optional)               │
│                                                                              │
│  COMMIT (Phase 6)                                                            │
│  └── progress-logger            Log to PROGRESS.md after EVERY commit        │
│  └── learnings-logger           Log gotchas to LEARNINGS.md                  │
│  └── feature-tracker            Update status to "done"                      │
│                                                                              │
│  SESSION END                                                                 │
│  └── /handoff                   Save context for next session                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## The Iron Rules

1. **Never skip TDD** - Write test first, watch it fail, then implement
2. **Never skip lint** - Run linter before EVERY commit
3. **Never claim "done" without evidence** - Show test output, show lint output
4. **One feature at a time** - Only one `in_progress` in features.json
5. **Log everything** - PROGRESS.md after commits, LEARNINGS.md for gotchas
6. **Orient at session start** - Run /orient before doing new work
7. **Handoff at session end** - Run /handoff before ending significant sessions

---

## Feature Lifecycle: From Idea to Done

This section shows how `/new-feature`, `/write-plan`, `features.json`, and the context files work together.

### The Complete Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      FEATURE LIFECYCLE                                       │
└─────────────────────────────────────────────────────────────────────────────┘

    IDEA                                                              DONE
      │                                                                 ▲
      ▼                                                                 │
┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐
│  1. NEW   │───▶│  2. PLAN  │───▶│ 3. START  │───▶│4. IMPLEMENT│───▶│5. COMPLETE│
│  FEATURE  │    │           │    │           │    │           │    │           │
└───────────┘    └───────────┘    └───────────┘    └───────────┘    └───────────┘
     │                │                │                │                │
     ▼                ▼                ▼                ▼                ▼
┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐
│/new-feature│    │/write-plan│    │feature-   │    │TDD cycle  │    │feature-   │
│           │    │           │    │tracker    │    │+ commits  │    │tracker    │
│Creates:   │    │Creates:   │    │Updates:   │    │Updates:   │    │Updates:   │
│• docs/    │    │• context/ │    │• features │    │• PROGRESS │    │• features │
│  features/│    │  plans/   │    │  .json    │    │  .md      │    │  .json    │
│• features │    │  YYYY-MM- │    │  status:  │    │           │    │  status:  │
│  .json    │    │  DD-*.md  │    │  in_prog  │    │           │    │  done     │
│  (pending)│    │           │    │           │    │           │    │           │
└───────────┘    └───────────┘    └───────────┘    └───────────┘    └───────────┘
```

### Step-by-Step Guide

#### Step 1: Create Feature with `/new-feature`

**When:** You have a new feature to build.

**What it does:**
1. Creates `docs/features/<feature-name>/` with:
   - `README.md` - Overview
   - `PRD.md` - Requirements
   - `IMPLEMENTATION.md` - Technical details
   - `TROUBLESHOOTING.md` - Debug guide
2. Adds entry to `context/features.json` with `status: "in_progress"`
3. Updates `docs/README.md` index

**Example:**
```bash
# User runs /new-feature
# Provides: "user-authentication" and "OAuth2 login with JWT tokens"

# Result:
# - docs/features/user-authentication/ created
# - features.json now has entry with status: "in_progress"
```

#### Step 2: Create Plan with `/write-plan`

**When:** Feature requires 3+ files or complex implementation.

**What it does:**
1. Creates `context/plans/YYYY-MM-DD-<feature-name>.md`
2. Contains bite-sized tasks (2-5 minutes each)
3. Includes exact file paths and code examples
4. Follows TDD structure for each task

**Example:**
```bash
# User runs /write-plan
# References the feature from step 1

# Result:
# - context/plans/2025-01-22-user-authentication.md created
# - Plan has 10-15 small, testable tasks
```

**Note:** `/new-feature` already set status to `in_progress`. If you used `/write-plan` without `/new-feature`, manually add to features.json.

#### Step 3: Implement with TDD

**What happens:**
1. Pick first task from plan
2. Write failing test
3. Run test → verify it fails
4. Write minimal code to pass
5. Run test → verify it passes
6. Commit with descriptive message
7. Log to `PROGRESS.md` using `progress-logger`
8. Repeat for each task

**Files updated during implementation:**
- Source code files (per plan)
- Test files (per plan)
- `context/PROGRESS.md` (after each commit)
- `context/LEARNINGS.md` (when gotchas discovered)

#### Step 4: Complete Feature

**When:** All tasks done, all tests pass.

**Completion Gate (ALL must be true):**
```
☐ All acceptance criteria verified (from PRD.md)
☐ All tests pass (run full suite, show output)
☐ Linter passes (exit code 0)
☐ Feature works end-to-end (manual verification)
```

**Update features.json:**
```json
{
  "id": "user-authentication",
  "status": "done",           // Changed from "in_progress"
  "tests_passing": true,      // Added
  "completed_at": "2025-01-22T15:30:00Z"  // Added
}
```

**Log completion:**
- Add final entry to `PROGRESS.md`
- Run `/handoff` if ending session

### File Relationships

```
context/
├── features.json          ← Single source of truth for feature status
│   └── Tracks: id, name, status, tests_passing, dates
│
├── plans/
│   └── YYYY-MM-DD-*.md    ← Implementation plans (one per feature)
│       └── Contains: tasks, file paths, code examples, TDD steps
│
├── PROGRESS.md            ← Append-only work log
│   └── Updated: After EVERY commit
│
├── LEARNINGS.md           ← Append-only gotcha log
│   └── Updated: IMMEDIATELY when gotcha discovered
│
└── WORKING-*.md           ← Session handoffs
    └── Created: By /handoff at session end

docs/features/
└── <feature-name>/        ← Feature documentation (one per feature)
    ├── README.md          ← Overview and links
    ├── PRD.md             ← Requirements and acceptance criteria
    ├── IMPLEMENTATION.md  ← Technical design
    └── TROUBLESHOOTING.md ← Debug guide
```

### Status Transitions

```
┌──────────┐     ┌─────────────┐     ┌──────────┐
│ pending  │────▶│ in_progress │────▶│   done   │
└──────────┘     └─────────────┘     └──────────┘
     │                  │
     │                  ▼
     │           ┌──────────┐
     └──────────▶│ blocked  │ (optional - if waiting on external)
                 └──────────┘

RULES:
• Only ONE feature can be "in_progress" at a time
• Cannot mark "done" without tests_passing: true
• Cannot start new feature while one is in_progress
```

### Quick Command Reference

| Stage | Command/Skill | Creates/Updates |
|-------|---------------|-----------------|
| Start feature | `/new-feature` | `docs/features/`, `features.json` (in_progress) |
| Plan feature | `/write-plan` | `context/plans/YYYY-MM-DD-*.md` |
| During work | `progress-logger` | `context/PROGRESS.md` |
| Found gotcha | `learnings-logger` | `context/LEARNINGS.md` |
| Complete feature | `feature-tracker` | `features.json` (done) |
| End session | `/handoff` | `context/WORKING-*.md` |

### Example: Full Feature Lifecycle

```
SESSION 1:
─────────────────────────────────────────────────
1. /orient                    → Check baseline healthy
2. /new-feature               → "payment-processing"
   • docs/features/payment-processing/ created
   • features.json: status = "in_progress"
3. /write-plan               → Create implementation plan
   • context/plans/2025-01-22-payment-processing.md created
4. Start implementing...
   • Task 1: Write test, implement, commit
   • progress-logger → PROGRESS.md updated
   • Task 2: Write test, implement, commit
   • progress-logger → PROGRESS.md updated
5. /handoff                  → Save context for next session
   • context/WORKING-20250122-1430.md created

SESSION 2:
─────────────────────────────────────────────────
1. /orient                   → Reads WORKING-*.md, features.json
   "Last session: Working on payment-processing, 2/10 tasks done"
2. Continue implementing...
   • Task 3-10: TDD cycle for each
   • progress-logger after each commit
   • learnings-logger when Stripe API quirk found
3. All tasks complete, tests pass
4. feature-tracker           → Mark "done"
   • features.json: status = "done", tests_passing = true
5. /handoff                  → Save context
```

---

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Writing code without tests | Write test FIRST, watch it FAIL |
| Committing without linting | Run `npm run lint` or equivalent FIRST |
| Saying "done" without proof | Show test output, show lint exit code 0 |
| Starting new feature while one in progress | Complete current feature FIRST |
| Forgetting to log progress | Run progress-logger after EVERY commit |
| Skipping orientation | Run /orient at EVERY session start |
| "I'll remember this gotcha" | NO - log to LEARNINGS.md NOW |
