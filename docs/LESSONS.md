# Distilled Lessons — why the protocol is shaped this way

Each rule below was paid for by a real incident. New lessons land here (with provenance)
and ship to every consuming project on the next kit upgrade — that propagation is the
kit's whole reason to exist.

## Coordination

1. **Claim before work; one owner per row; file fences are hard.**
   *Provenance:* three concurrent sessions partitioned ~15 workstreams in one evening with
   zero file collisions — only because every row carried an explicit file fence and claims
   were committed before work started (origin project, 2026-08-08).
   PRS (2026-11-07): A design that names a file outside the brief's fence is a fence extension
   to ask for before editing, never one to report after.

2. **Worktree isolation for every implementation agent.** Concurrent sessions and their
   subagents never share main's working tree; non-isolated agents silently co-edit files.
   *Provenance:* origin-project memory `feedback_isolate_worktree_for_concurrent_sessions`.

3. **NEVER `git stash` inside a worktree agent.** Stash refs are SHARED across all
   worktrees of a repo; two agents stashing concurrently popped each other's WIP. Prove a
   RED state via `git commit` + `git reset --soft`, or copy files to a scratchpad.
   *Provenance:* origin-project B1/B2 stash collision, 2026-08-08.
   PRS (2026-11-07): `git rebase --autostash` is a stash in disguise; a board-write recipe
   already requires a clean tree, so it is never needed.

4. **Sequential reconciles; exclusive deploy.** Land one worktree at a time onto main;
   claim the DEPLOY row before deploying. Parallel landings lose work; racing a deploy
   corrupts the cutover.
   *Provenance:* origin-project M376/M377 two-session coordination.

5. **Commit board edits immediately.** Uncommitted board state is invisible to other
   sessions and gets swept into someone else's commit.

6. **Stale status docs cause duplicate rebuilds.** A "BUILD pending" line for work that
   was actually finished on a branch nearly caused a full re-implementation. When work
   lands somewhere non-obvious (a held branch), the status doc must say so, with the
   branch name and the reason it's held.
   *Provenance:* origin-project ADR-0041 near-miss, 2026-08-08.

## Verification

7. **Independent verify at every hand-off edge.** A sibling implementation+test pair can
   confabulate the SAME wrong belief — wrong code + wrong test agree, and TDD shows green
   that means nothing. The verifier receives the contract only (spec + diff), never the
   implementer's reasoning, and judges against canonical ground truth (the spec/ADR/
   constants), never against a sibling's test.
   *Provenance:* origin-project memory `feedback_multiagent_false_green_trace_semantics`.

8. **The verifier reports; it never edits.** A verifier that "helpfully" fixes masks the
   drift it exists to catch.

9. **No vacuous green.** A check that found nothing wrong and a check that ran on nothing
   are indistinguishable unless you assert the match/population count — "0 failed" out of
   0 run is not a pass.
   PRS (2026-10-26): A check fed by a file or tool can silently run on less or nothing (see 10):
   count each population, probe selections included (see 69), and tie each pass line to its
   checks.
   PRS (2026-11-07): A check that cannot find one of its inputs says so in its output; a silent
   pass over a missing file, or a test filter matching no test, is a vacuous green (see 152).

10. **Read the REAL pass line, unpiped.** Pipes mask exit codes; a background-task
    completion notification masks a failing exit; a process can print its pass summary and
    then crash in teardown. Assert the literal "N passed / 0 failed" summary AND a clean
    exit, from output you captured yourself.
    *Provenance:* origin-project memories `feedback_pipe_masks_exit_code`,
    `feedback_background_test_notification_masks_exit`.
    PRS (2026-10-26): Score every falsify result and failure count from the full, untruncated
    log, never the gate's shortened output, because a red past the cut reads as a surviving
    mutant (see 9).
    PRS (2026-11-07): Copy the pass line from the log, never retype it (padded spacing fails a
    literal compare); when a listing was piped through `tail` or parallel output interleaves,
    score by the summary count plus a per-name grep of the full log, and read an "aborted" line
    above a normal pass count as a failure.

11. **Gate red ≠ code red.** Know the project's infra-flake modes (e.g. one test
    container per file saturating Docker) and encode the trusted gate + the never-run
    commands in `ORCHESTRATION.md`. An untrustworthy red wastes every session's time.

12. **Gate green ≠ boots.** Unit-green says nothing about schema/seed/boot integrity;
    migrations need a boot or constraint check in the gate for their change class.
    *Provenance:* origin-project memory `feedback_gate_green_but_boot_crashloops`.

13. **Re-verify subagent claims at reconcile.** "Pre-existing failure", "flake", and
    "done" are claims, not facts, until the reconciler re-runs the named suite in
    isolation and sees it with its own eyes.
    *Provenance:* origin-project memory `feedback_verify_subagent_failure_claims`.
    PRS (2026-10-26): Report only the failures a change adds over an untouched base, and blame a
    merge only when the failing output is not byte-identical on the merge and both parents.

## Scope discipline

14. **Locked constants / spec-locked formulas need the human's sign-off.** Subagents get
    the list of locked items in their brief and treat it as read-only.
    *Provenance:* origin-project memory `feedback_guard_locked_constants_from_subagents`.

15. **The board is institutional memory at the hand-off grain.** Closed rows keep their
    verifier verdict, real gate lines, and released fences — the next session's context
    starts there.
    PRS (2026-11-07): Lists copied from a handover block are hypotheses; rebuild them from the
    board rows before reusing them in a log or a card.

## Orchestrated autonomy (harvest 2026-08-19 → 2026-08-21)

16. **Per-session row-ID prefixes — never a shared counter.** "Read the highest and add one"
    is a read-then-write with no lock; sessions append in different places so git never
    conflicts, both ids go live, and a grep returns two unrelated rows that look deliberate.
    Prefix = session tag (`O7-1`, `FQ-2`); collisions become impossible by construction.
    *Provenance:* six manual reconciliations in two days (origin project).

17. **Milestone/log numbers are allocated through a claimed LOG slot** (same shape as the
    DEPLOY slot). Any shared monotonic counter needs a single allocator while concurrent
    sessions run.
    PRS (2026-11-07): Any id or code minted on a branch collides at the merge; mint on main
    through the allocator in one step.

18. **A verify arc of DEVIATES → fix-roundtrip → delta-PASS is the system WORKING.** The
    verifier's findings are the record's most valuable content; a fully green suite can
    still carry spec drift. Roundtrip fixes land at the layer the finding names, falsified
    one-red-each.
    PRS (2026-11-07): A fix the verifier proposes for a finding is re-checked against the
    finding's own test, so the rule it names becomes true, not merely different.

19. **Announce resource windows on the board** — gate runs, integration/testcontainer runs,
    deploys, AND dev-stack boots on a shared daemon. A sibling's sweeper, deploy, or
    resource-hungry run is a killer for anything it can't see.

20. **After ANY interrupted cherry-pick / rebase sequence: count the picks.** A conflict
    abort can silently DROP a commit from the sequence; compare landed commits against the
    branch's commit list before declaring the landing complete.
    *Provenance:* a green branch's GREEN commit vanished from a landing mid-sequence
    (origin project, 2026-08-21); caught by counting the landed commits against the branch's
    intended list — the byte-diff against the branch tip was the repair's verification,
    not the detection.

21. **Mutation/falsification commands: one explicit target tree, stderr visible.** Never
    leave earlier path guesses in a compound command; never `2>/dev/null` anything that
    edits files; after restore, diff-verify EVERY tree the command string could have
    reached, not just the one the test reads. And a mutant you haven't diff-verified as
    APPLIED proves nothing.
    PRS (2026-11-07): Copy from the committed tree (`git archive`), never the working tree, and
    assert the copied file equals the tip blob; a mutant loop stops on a failed apply or
    restore, never only prints; restore from a copy outside the scratch and `cmp` after (see
    47).

22. **A change that ADDS test output needs one pass through the real gate stage** — gates
    that classify stage output by pattern make output part of the interface; a realistic
    fixture string in test logs can impersonate an infra-error signal and false-RED every
    session's gate. Capture loggers in tests (and assert they fired); never reword a
    fixture away from the real message to dodge a classifier.

23. **Doc-agent diffs are APPEND-ONLY and fact-checked line-by-line before commit.** A
    delegated log write once replaced a 32k-line institutional log with an 82-line stub,
    with fabricated details; `git diff` deletions must be zero for an append, and every
    factual claim is checked against what actually happened.

24. **Retro-before-clear is a HANDSHAKE.** `/clear` destroys unpersisted context; the retro
    converts it into memories and tied-off state. Order: retro order → the session's
    explicit "retro complete" → only then close the terminal and relaunch it with an explicit
    `--model` (a bare `/clear` keeps the old model), one terminal at a time.

25. **No mid-orchestration `/compact`.** Context quality is load-bearing at hand-offs;
    compaction mid-arc loses exactly the correction/decision detail the next phase needs.
    Context pressure → the retro-before-clear handshake instead.

26. **Inserting a step into an ordered, PERSISTED sequence is a migration.** If a cursor
    stores a position and only resolves forward, a mid-list insertion strands everyone
    already past that index — precisely the users it was written to protect. Ship the
    backfill + a guard in the same change. Projects carrying such sequences should elevate
    this into their own CLAUDE.md.
    *Provenance:* a tutorial-step insertion soft-locked the project owner's own account
    (origin project).

27. **Never expose user PII in public channels or shared artifacts** — usernames, emails,
    ids stay out of anything that leaves the project's private surface.

## Multi-session hardening (harvest 2026-08-22 → 2026-09-29)

28. **The INDEX is shared, not just the tree.** Explicit staging protects your commit from
    others' files, not your staged file from THEIR commit. Board writes in the shared
    checkout: HEAD guard → `git diff HEAD --quiet` → `git add <path> && git commit` as one
    command → push. "Nothing added" + "up-to-date" right after a write = you were swept.

29. **`git pull --rebase` races on the shared `.git/FETCH_HEAD`** ("Cannot rebase onto
    multiple branches"). Use `git fetch origin && git rebase origin/main`. A `cannot lock ref`
    exit is a lost fetch race — retry once; never wrap it in a loop that ends on `sleep`'s 0.

30. **Guard the shared checkout's HEAD before any write.** A sibling's failed `cd` can leave
    it detached on a trial branch; a later push of `HEAD:main` then ships ungated commits.
    Check `git symbolic-ref -q HEAD` = `refs/heads/main`; push `origin main`, never `HEAD:main`.
    PRS (2026-10-26): In multi-worktree sessions run every git write as `git -C <worktree>`,
    since the shell's directory can reset to the shared checkout; reads may stay bare (see 2).

31. **Push a `merge --no-ff` immediately.** A plain rebase before the push linearizes the merge;
    the builder's SHAs never reach origin and a branch stacked on them conflicts later.

32. **Run the gate from inside your own worktree.** A gate script that `cd`s to its own
    directory gates the tree it lives in and prints a legitimate green for a tree you are not in.

33. **Siblings verify siblings — not subagents.** A subagent the seat spawns inherits the seat's
    framing; a peer session has its own context. Nobody verifies their own row, no mutual
    pairs, the verifier reports to the seat, and every verdict says DERIVED or
    CONSISTENCY-CHECKED — only the former is verification.

34. **A dedicated validator that never builds** is independent of every row by construction.
    Hand it READs, re-reads, train checks and falsification; never a build or fix round.

35. **A narrative board briefs its own verifiers.** Keep the board to status; briefs go to the
    builder by message; archive verbatim past ~60 KB and grep archives, never read them whole
    (an unreadable board is the same as no board).
    PRS (2026-11-07): A row narrative written into a memory note reaches the verifier's session
    unasked; narratives stay in the row's scratch or brief, and READY names the notes read.

36. **`ListAgents` is liveness, not readiness.** Terminal uptime survives `/clear`, so a fresh
    context and a spent one look identical. Rosters come from READY signals — otherwise the
    seat waits for siblings while siblings wait for the seat.

37. **Measure context; never estimate it.** Sum input + cache_read + cache_creation off the last
    assistant turn. `bytes ÷ 4` over-reports 30–60% with an unstable bias. The window is not in
    the transcript — read it from the session's own env block; a threshold calibrated for 1M
    never fires on a 200K session before it dies.
    PRS (2026-10-26): Quote every fill number and time stamp from the measuring script or
    `date -u` run in that same turn, never from memory; remembered figures drift.
    PRS (2026-11-07): The env block can show the bare model id without its window suffix; the
    launch arguments (`ps -o args= -p $PPID`) are the truth, and READY takes the window from
    them.

38. **Measure the right object.** Identify a session from an authoritative id, never "most
    recently modified". Checking a property of the wrong object raises confidence, not accuracy.
    PRS (2026-10-26): For your own context fill, take your identity from your own listing or env
    block and measure that session's transcript, because the newest file in the folder may be a
    sibling's.

39. **Recycle launch-first, then SIGTERM.** Open the fresh session, wait until its process
    exists, then SIGTERM (not KILL) the old one — no seat is ever empty and the old transcript
    flushes. Only after "retro complete".

40. **All human approvals route through the seat.** Siblings stop and message the seat; the seat
    batches questions to the human in ONE terminal. Scattered prompts across terminals stall
    silently when nobody is watching that window.

41. **A suite nothing runs rots silently.** A fast DB-free gate is right per change, but some
    exhaustive sweep must run before trains or nightly — a change can be green on its own
    evidence and break a suite one directory over.

## Enumeration, evidence and honest claims (harvest 2026-08-28)

*One 12-hour orchestrated session, three sibling builders, two deploy trains, nine rows
shipped, two rows killed. Every lesson below came from a verifier finding, a sibling
correcting the orchestrator, or a sibling correcting itself.*

42. **The enumeration is the deliverable; the fix is the easy part.** Two independent rows
    failed identically the same day: each brief said "find every X" and then *illustrated*
    with three examples, and each builder fixed exactly those three. Independent
    re-enumeration found **eight** and **thirteen**. An illustration placed inside a
    requirement gets read AS the requirement. Name the enumeration as the artifact you
    want, and have the verifier rebuild it from scratch rather than check the builder's.
    *Provenance:* origin project — one row guarded 3 of 8 sites, another fixed 6 of 19 comments.
    PRS (2026-10-26): Test a scan's pattern on the real file before it builds the list; a
    verifier rebuilding from a fresh dump reports items newer than the seed's build as seed
    drift.
    PRS (2026-11-07): The population comes from every place the item is stored, and the list
    must be non-empty; for screen text, read the shipped files, never a hand list of constants.

43. **A term-sweep converges only when every hit gets a written verdict.** Iterative
    "search and fix" rounds do not converge: round 1 found 9, round 2 fixed 6, round 3
    found 11 more. The cause is **not** vocabulary — the searches were fine. A grep over a
    large repo returns mostly noise, so the reader **unconsciously filters by plausibility**
    and a hit in a file that looks like someone else's area is skipped without a decision
    being made. Forcing a typed verdict per hit removes the filter, because "unrelated"
    must be *written* rather than assumed. Generalizes to any audit-by-grep.
    PRS (2026-11-07): Report the raw hit list first, then the verdict per hit; a judged count
    hid five of six hits.

44. **When a fact is documented more than once, fixing ONE copy makes the others harder to
    find** — the fixed copy stops matching your grep and reads as done. Work twin-first:
    find a poison case, look for its bleed twin immediately; fix a mirror, fix its source.
    *Provenance:* one type file carried the same rider doc **four** times; a round whose
    stated purpose was "I fixed one half and left the twin" then fixed the wrong pair.

45. **A component test cannot see a regime that never mounts the component.** A feature
    shipped fully working — and absent on the one device/breakpoint the original reporter
    used — because a different component is substituted there. All its tests rendered the
    component directly. Pin the **composition** that chooses the component, and assert the
    regime is actually active so the test cannot pass by falling through to the other path.
    PRS (2026-10-26): The same holds for entry paths: pin each way into a feature besides its
    top-level entry with a check that measures the change it should cause, not only that the
    page loads.
    PRS (2026-11-07): Probe a lifecycle fix through the running application object, not the
    window alone; the framework's own object can act on the same message first.

46. **A guard that compares NAMES cannot see TYPES.** An entire family of drift guards
    compared key sets; flipping a field's declared type in the *canonical schema* left the
    dedicated drift guard green at 47/47. The only backstop was the compiler, and only
    *incidentally* — one file built typed literals while its neighbor used a cast. Decide
    explicitly whether a guard covers types, and write down which backstop you are relying
    on. Relying on one without knowing it is the failure.
    PRS (2026-10-26): In a check or review, never accept a helper call on the strength of its
    name; open what it returns, by reading its body or calling it on a known case.

47. **A restore check must assert TWO things: tree clean AND the fix still present.** A
    mutation-restore run against a baseline that never carried the fix is a **delete**, not
    a restore — and it prints `nothing to commit, working tree clean` plus a GREEN gate on
    the *pre-fix* SHA. Clean status alone cannot distinguish restored from deleted. Always
    commit GREEN before mutating.
    PRS (2026-10-26): After undoing a planted bug, wipe the compiled cache, or the bug can still
    run; run gates with compiled-file writes off, so cache files never dirty the tree (see 63).
    PRS (2026-11-07): A sync by size and time skips a restore made within the same second; sync
    by checksum, and disable bytecode caches for the run.

48. **A mutant that reds for the wrong reason is not evidence.** A "mutant" that *inserted*
    a duplicate step rather than *relocating* one produced a red — but proved only
    sensitivity to placement, not that the guard catches the reorder it was written for.
    Diff-verify every mutant; a red you wanted is the easiest thing in the world to accept.
    PRS (2026-10-26): A red counts only from a page this run built and from the check predicted
    in writing beforehand, and a mutant's diff must remove or change the guarded line.

49. **Report the non-findings.** An audit that finds a defect in everything it inspects is
    usually an audit performing thoroughness — the useful output is *which* items were wrong
    and *why the others were not*. For a sweep, the negative results are half the
    deliverable: "your two hypotheses are falsified across 39 suites" is what lets an
    orchestrator ship without hedging.

50. **Propose an omission with the evidence that makes it safe, not the conclusion.** "I
    skipped the integration re-run — here is the diff proving nothing in those paths
    changed" is a thirty-second decision. "Should be fine" costs a full re-run.

51. **A test file that overstates its own coverage is worse than a missing test, because
    the next reader stops looking.** A coverage claim is a claim: it needs the same evidence
    as a behavioral one. *Provenance:* a header fixed an over-claim about code scope and
    introduced a fresh one about test coverage **in the same edit** — the tidy sentence
    arrives first, and repairing a claim feels careful enough to skip checking the new one.
    PRS (2026-10-26): A pin that only prints a value the builder claims is the same over-claim:
    mutate the claim away and predict green, and a mutant that survives is the finding.
    PRS (2026-11-07): Every "caught" or "closed" form named in a commit body maps to a test row
    or a mutant id.

52. **The hedge is the untidy part, and a write-up wants a clean rule — whoever is writing.**
    An orchestrator turned a builder's "I ran no sweep" into "patience saved a sibling's
    run," and its "a small piece of evidence" into "a natural experiment." A builder turned
    "three of six sites guarded" into "the state is unreachable." **The self-inflicted case
    is harder to catch, because there is no second party whose qualifier you notice yourself
    dropping.** When a builder qualifies a claim, the qualifier IS part of the finding.
    PRS (2026-11-07): A builder's hedge on its own output ("correct, not rich") is a fix-round
    signal, never a note on the card.

53. **Sweeps run from a SHA-pinned worktree, and you must replay your scoping patterns
    against the full file list before claiming coverage.** A shared checkout moves under a
    long sweep as siblings commit, making chunks incomparable and attribution worthless.
    And scoped chunks silently drop anything the patterns miss — one suite matched no chunk
    pattern and had never run; the report would have said "149/149" having run 148. **The
    omission is invisible from inside the chunking.**

54. **A standing instruction that a tool violates automatically is not a standing
    instruction.** "Don't clean the shared containers" was unachievable, because the gate
    invokes that cleanup at stage 1. The fix is a knob (an env var raising the liveness
    floor), not a rule. Corollary: **"I didn't run X" is not the same claim as "X didn't
    run"** — report on the tooling's behavior, not only your own actions.

55. **Couple two changes into one train when the INTERMEDIATE state is worse than either
    endpoint** — not merely because they are related. Shipping an ordering fix without its
    replay-parity companion would have released a version whose own fix made replays lie.

56. **Memory recall runs on the description, not the body — check what a description is
    retrievable BY, not just whether it is correct.** An accurate, indexed, week-old memory
    answered a question three sessions had; none found it, because its description named the
    *subsystem* and never the *tool everyone runs*. **A memory retrievable only by people
    already thinking about its topic is retrievable mainly by people who don't need it.**
    This is a writing-time discipline. The wrong conclusion is "write more memories."

57. **Knowing a rule does not prevent the failure it describes.** A builder cited the
    restore-was-a-delete rule to the orchestrator hours before walking into it. Recall is
    not the bottleneck; *applying a rule while inside the situation it describes* is a
    separate skill. Build the check into the procedure rather than trusting recall.

58. **Killing a row on zero population is a good outcome, not a wasted afternoon.** Two rows
    died that way in one session — one because a backfill described in the *future tense* had
    actually shipped five weeks earlier, so an audit believed the comment over the data.
    Require the population count *before* the build, and say "zero" out loud so nobody
    re-files it.
    PRS (2026-10-26): A number in a code comment carries no commit; before offering one for a
    decision, re-run the measurement on the current base and quote the commit SHA beside each
    number.

59. **Fail-open vs fail-closed is the load-bearing property of any client-side guard.** A
    disable derived from data that may not have loaded must degrade to *enabled* — the
    server's refusal is the real guard. A false disable silently denies a legitimate action
    with no error and no recourse, which is far worse than the dead click it replaced.

60. **A guard that cries wolf gets deleted.** Measure a marker/heuristic set against the real
    corpus before shipping it: a first-choice marker matched three files, two of which were
    unrelated. Precision is what keeps a guard alive long enough to catch anything.
    PRS (2026-10-26): The other side is recall: a parser of hand-written markers must accept
    every form the source uses, and an overflow walk must skip hidden content (the opposite
    trap, a missed overflow, is 74).
    PRS (2026-11-07): Count a new check's refusals before and after on the real corpus, with a
    diff, before its first green; a detector right on one kind flagged forty real pieces of
    another.

## Guards, gate logs and worktree git (harvest 2026-10-15)

*One orchestrated day of tool-building rows, each read by a sibling verifier. Every lesson below
came from a verifier finding or a falsify run that went red where the builder expected green.*

61. **A guard that scans state must run before any step that erases what it scans, or read that
    step's record of what it erased.** A guard placed after the erasing step can never fire and
    prints green on every input; prove it red by mutating the writer of its input, not only the
    guard.
    PRS (2026-10-26): A guard's count holds only for the stage it ran at, so run it again after
    the last step that moves its input (see 87).

62. **A measuring guard draws its measured landmarks on the output it judges.** A sample too
    sparse to land on the feature can still give a plausible number and a clean log; a
    measurement nobody can see is a measurement nobody can check.

63. **Write the gate log's SHA line after the gate slot is acquired; commit first, and never
    edit the tree while a gate waits unless it runs from a snapshot.** The queue tests the tree as it is when the slot frees,
    so a header written earlier can vouch for code that was never tested. Extends 32.
    PRS (2026-11-07): Untracked files ride into the gate's copy, so dirty counts them; a mutant
    applied in the same worktree while the gate ran voids the run; any commit after the gate
    started restarts it, the record-only commit excepted (see 188); keep every gate log, a rerun
    never overwrites the red one.

64. Retired, see 30.

65. **Falsify a path or name filter with its escape variants, and prove each layer bites on its
    own.** A filter can check only the first path segment and let a `..` path through, and a
    layered guard whose inner layer never fires alone is one guard, not two.
    PRS (2026-11-07): Test a filter with a table of (input, expected) rows through its own
    function, every spelling in one build with a plain control among them; escape every
    character the target interpreter treats as a quote, not only ASCII, or pass the value
    through an encoded command or an environment variable.

66. **A check through a clamped accessor can never fail: compare the underlying value.** A
    getter that caps its result reads exactly the cap on every overflow, so a "does not exceed
    the max" test through it passes on what it should catch.

67. **A probe number that feeds a human ruling is cross-checked by a second path first.**
    Reproduce it another way (a fixture built by the real code path, or a real run) and say both
    agree; a wrong number shapes a ruling that must then be re-asked.

68. Retired, see 74.

69. **An input mutant proves it changed the measured feature before its PASS or FAIL counts.** A
    mutation that moved nothing makes a pass look like proof and a fail look like a hole, so log
    the measured value before and after it, next to the verdict (see 21 and 48 for code
    mutants).

70. Retired, see 48.

71. **"Old data" fixtures are built by the OLD code, in its own worktree.** Fixtures written by
    the new code in "old mode" carry its assumptions, and can pass a migration that real old
    saves would break.

72. **A claim of "within plus or minus N percent" is checked per row, not on the total.** A
    total within tolerance proves only that the errors cancel, so report the change for each
    source and apply the tolerance to each row.

73. **Test a lock's atomicity on the filesystem where the real lock lives.** Exclusive create
    can behave differently on a network-style mount than on local disk, so a race run only on
    local disk says nothing about the mount.

74. **A measuring guard must not let the measured object choose its own landmarks.** Landmarks a
    heuristic finds move with the input they judge, so pin them to something the input cannot
    reshape and fail closed when they are missing (see 62).
    PRS (2026-10-26): A guard whose limits are fractions of a total takes that total only from
    parts the input cannot extend, or refuses an input whose reference parts are unexpected.

75. Retired, see 48.

76. **After a scripted marker-to-marker cut, grep for the lines it removed.** The range can
    swallow lines meant to stay, and nothing fails until much later; check each removed line was
    meant to go before the next step builds on the file.

77. Retired, see 38.

78. **A lock helper's release removes only the exact line it wrote, and its default owner is
    unique per run.** Fixed default names let two unnamed runs each believe they hold the lock,
    and a release that skips comparing the owner line can free a lock another run has taken
    since (see 73).

79. Retired, see 37.

80. **Parity with the old version is proved on the whole report, not on the numbers you
    picked.** Per-number checks can all pass while rules behave differently: diff the new full
    output against the old, then make the diff fail on purpose (see 40 and 72).
    PRS (2026-10-26): After moving a threshold or scale, probe every input that feeds a rule on
    both versions, reading raw values, never through a clamped accessor (see 66).

81. Retired, see 80.

82. **Never chain a commit after a gate with `;`.** The commit then runs even when the gate
    fails, and the log shows a green-looking commit on red code. Join them with `&&`, or read
    the pass line and commit in a separate step (see 63).
    PRS (2026-11-07): `&&` only after the test command's own exit status, or a grep that matches
    the pass line alone; a grep that matches both outcomes commits red code, and after a pipe
    `$?` is the last command's (use `PIPESTATUS[0]` or no pipe).

83. Retired, see 80.

84. **A test that takes its expected value from the constant it guards cannot fail on that
    constant.** Change the constant and the expectation moves with it, so the check stays green;
    write the ruled value into the test itself (see 48).

85. Retired, see 80.

86. **"Every item is covered" comes from a script over the list, never from memory.** Memory
    misses items; loop over the list's real source, print each item with where it is covered,
    and quote that output with its count.
    PRS (2026-11-07): The list is extracted from the final text by a pattern, never hand-picked;
    a hand list missed two SHAs the draft cited.

87. **When a repair pass runs before a check, report the check's count before the repair too.**
    A local cleanup can turn a defect into one the metric no longer measures while the gate
    reads green; a large drop is a finding, not a pass (see 62).

88. **After a machine crash, audit before assigning any work.** A crash can leave unpushed
    branches, uncommitted files, lost gate logs and locks naming dead sessions, so every sibling
    waits until the audit is done.

89. **Relay only a settled human ruling to a builder.** Forwarding each step of the human's
    thinking sends the builder a string of specs, each superseding the last; collect the whole
    answer and confirm it is final first.

90. **A visual check done on thumbnails is not a check; give each property its own measured
    check.** An image can look right at thumbnail size and be wrong at full size, and a metric
    for one property passes errors in another.
    PRS (2026-11-07): A numeric pass still gets one look at full size beside the previous
    version, and each measure's known blind spot (an un-inked shape, a hollow inside) is planted
    as a known-bad.

91. **Prove a new check red on the artifact the human actually rejected, not only on a made-up
    broken case.** An invented case can fail in a way the real one does not; a check that stays
    green on the rejected artifact does not guard that complaint (see 69 and 48).

92. **When inheriting a row, list its scratch files by modification time against the branch
    tip.** A session that ended abruptly can leave unlogged attempts newer than the last commit;
    read, log or discard each one on purpose (see 88).

93. Retired, see 105.

94. **Before proposing how to satisfy a refusing check, trace where the check takes its input.**
    The check may read a live, derived value rather than the stored field, so an edit to the
    input you assumed changes nothing (see 67).

95. Retired, see 9.

96. **A gap you have not isolated is "not explained", never "noise"; a quantity is "display
    only" only after every consumer is traced.** A gap written off as noise hides its cause, and
    a display-only value can feed a rule two calls away (see 72 and 80).

97. **A failure that depends on the path cannot be bisected by one run per commit.** When it
    shows only on some routes, a good run proves nothing: reproduce the fact the crash frame
    names in a minimal script, and prove the fix with a check that can fail (see 48).

98. **A liveness guard compares to the thing it guards; pasted for another kind of object it
    silently aborts.** It then fails every time and quietly stops a scripted run while the lint
    and smoke tests stay green; prove it red by pasting it onto the other kind (see 48 and 97).

99. **A refit that wins back broken bars can quietly move the bars it does not score.** Put
    every bar that must hold into the refit's cost, not only the ones that failed, and report
    all bars before and after (see 62 and 94).

100. **Before wiring an effect to an event, prove the event can fire where the effect lives.**
    If the event never runs there, the hook is dead code that only a probe can reach; show it
    firing from the real path, not the probe (see 105).
    PRS (2026-11-07): An injected failure or delay is shown to take effect before its absence
    counts; a synthetic click moves no focus, so a focus claim is driven with trusted input and
    a control run.

101. **Prove a cause by pinning one path at a time, and measure options as patch scripts on the
    probe's temp copy.** Changing several causes together leaves a better result unattributable,
    and editing the product to try options leaves changes to revert (see 96). A scalar meter can
    move with each fix while the defect stays (see 90). PRS (2026-10-26): When a new random draw
    shifts a seeded run, compare the old code plus only that draw on the same seeds before
    calling it a fault.

102. Retired, see 10.

103. **Size a parallel fan-out by free memory, not by cores.** A fan-out sized by core count can
    start many heavy processes at once and run the machine out of memory; start each heavy
    process only when enough memory is free (see 88).

104. **Stopping a background shell task leaves its child processes running: stop each heavy run
    by the process id recorded at launch.** A leftover child keeps holding memory and locks, and
    a stop by name match can kill your own shell or another session's run.

105. **A READ of a factor in a shared function lists every caller.** A caller may apply the
    factor again or skip it, so grep every caller, quote the list, and state for each whether it
    applies the factor itself.
    PRS (2026-10-26): A test drives each call site or checks its exact call text, because a
    helper can be right while a caller applies its factor again.
    PRS (2026-11-07): The same for a shared style, helper or raised event: list every user
    before changing it; a gate placed on a function gates everything inside it.

106. **After every delivery, assert the delivered file's md5 against its source.** An older or
    partial copy left at the destination can be used as if it were the source, so compare in the
    same command that delivers it and fail the step on a mismatch.

107. **Before a long optimization against extrapolated targets, check the targets can be met
    together.** Targets each extrapolated on its own can drift apart until no solution meets
    them all, and the run stalls for hours (see 99).

108. **Run a long background chain as one script, memory-gated per step, with a status file per
    step.** Separate commands can be reaped partway with nothing to show which step finished;
    per-step status shows exactly where the chain stopped, so it can resume there (see 103 and
    104).

109. Retired, see the falsify skill (its "Discriminating mutant" step).

110. **Falsify a check in the mode the real gate runs it.** A check with a quick and a strict
    mode may be unable to fail in its default one, so use the gate's own flags, environment and
    mode, and make the gate name that mode.

111. **A stamp that records how something was made counts only if something reads it and stops
    on a mismatch.** A stamp nothing compares with the live settings can never catch a mismatch;
    prove its reader red by changing one setting (see 80).

112. **Before pinning an anchor per frame to a measured extreme, measure the motion the pin
    adds.** Each frame's extreme moves with the content, so the pinned result can bounce more
    than the source drifts (see 90).

113. **Measure a "missing" step's output at every later stage before rewriting it.** A step that
    looks idle may be firing but under-correcting while later stages widen the gap; fix the
    stage where the gap appears, not the one that looks idle.
    PRS (2026-11-07): When every round fails the same way, measure the input for the property
    the target needs before another round.

114. **After a batch fix, a mask-only composite plus an md5 count proves the fix touched only
    what it should.** Re-running the whole pipeline changes pixels outside the fixed area; the
    count of changed outputs must equal the number meant to change (see 80).

115. Retired, see 144.

116. **Judge a guide on every view before spending a long job on it.** A guide right from one
    view can be wrong from another, and the fault shows only after the slow job has run
    (see 107).

117. **A pick-by-eye sheet shows the candidate between fixed anchors, at one scale, on one
    baseline.** Candidates at different sizes and baselines, with numbers on the picture, cannot
    be told apart by eye.

118. Retired, see 61.

119. **When the look is the requirement, a headless check of the model is not the check; read
    the drawn pixels and add a mutant only the pixel read can kill.** The model can hold the
    right numbers while the drawn result is wrong, and a pin beside the draw call cannot see the
    effect (see 84 and 100).

120. **A probe run that dies part-way gives no results: rerun the whole set.** If a cut-off
    run's numbers count, partial results pass as findings; quote only from a complete run (see
    9).

121. **A metric that ranks things must be run on the reference pair it is meant to rank, and on
    wrong references.** A broken meter can rank candidates against what a person sees; if every
    right pair does not beat every wrong pair, fix or drop it (see 69). PRS (2026-10-26): A
    camera check must fail shifted copies of a good picture and pass the reference itself
    (see 91 and 124).

122. **Before a ladder of edits, test the largest step on the hardest case; calibrate an edit
    check with a null edit and a mutant.** A method's size ceiling only shows on its largest
    step, and an uncalibrated check's fail may be its own quantisation floor (see 74).
    PRS (2026-11-07): Run every agreed pass line on the reference itself before round 1: if the
    reference fails, the lines conflict and no round can pass; a check proven only on known-bads
    can still refuse the right answer.

123. **A shape gate on an edited outline is relative to the original over the same rows, checked
    at several scales, and reported as a pass fraction.** Absolute bars flag the figure's own
    bends, one scale misses flat-bottomed defects, and a bar at the noise floor passes only in
    pockets of the parameter grid (see 110).

124. **A validator needs a pin that feeds it a planted fault.** A validator run only on clean
    real data has branches nobody has proved: plant a bad copy for each branch and require a
    refusal (see 98). When the fault drops a record, predict one fault per reference to it; a
    different count is a finding (see 48).
    PRS (2026-11-07): Plant the weakest real instance, not the strongest, from literals, never
    from the constants the mutant changes; one single-fault plant per verdict line, each with
    distinct content; re-place plants when the allowed set changes; check the planted state
    exists on disk; plant under the real path and name; plant each wrong kind, a same-hue add
    and a move-out included.

125. Retired, see 9.

126. **Rebase only before the first push; after it, cherry-pick onto the pushed tip and
    re-gate.** A rebase after a push forces a force-push or leaves two histories (see 88).

127. **Compensating a non-deterministic generator's drift needs two rounds that agree first.**
    The drift differs each run, so a one-shot compensation can over-correct; compensate only
    when two independent rounds agree, and once at most.

128. **A design row's seam table includes the owner's earlier rulings on the topic, built or
    not.** A proposal that ignores an unbuilt ruling reopens a settled question, so grep the
    decisions file for the topic before proposing.

129. **Parallel builders in one worktree: exclusive file lists, shared hooks committed first,
    one locked test runner; silent side effects and singletons get their own checks.** A claim
    kept true by a silent side effect needs its own assert and a mutant that removes the effect.

130. **Flip a policy constant once before calling a change green.** The pins that go red are
    tied to the value rather than to the rule; rewrite each relative to the constant, or name it
    as bound.

131. **A steadiness check measures at one fixed scale per route.** A pipeline that normalises
    each frame (to the same height, say) hides exactly the drift a size or steadiness check is
    looking for (see 112).

132. **A two-sided bound needs a mutant per side.** One side can survive a mutant while the
    other side holds the check red, so falsify each side separately and report both results
    (see 48).
    PRS (2026-11-07): A guard over a list needs one plant per entry, never nested; a key used
    twice needs a mutant per use; a character set is sampled one member at a time.

133. **An automated quick reply to a person can invent facts or promise work nobody started;
    correct it in the full answer and never build on it.** Build only on what the person
    actually said, not on what the quick reply claimed.

134. **While the base model is not agreed, send one proposal, not a fan-out of questions.**
    Detailed questions ask the person to rule on parts of something that may change; open them
    after the base is agreed, one per real fork.

135. **Every async UI action gets one check with a deliberately late stub.** A stub that
    resolves at once hides in-flight races, such as a redraw that re-arms a button while a save
    is still pending.
    PRS (2026-11-07): The delay or gate starts at the test's own action, not at the page's
    subscribe, and stays set until the call is sent.

136. **Before a long redo round, put today's result beside the owner's own reference.** A
    summary of what someone wants can carry the wrong detail, and the whole round then chases it
    (see 107 and 116).

137. Retired, see 101.

138. **Fix a chance flake by forcing the roll at the step, not by counting repeats.** A streak
    of passes proves nothing when the roll barely varies across runs; show the test fails
    exactly when the roll is under the chance (see 97).

139. **A test that passes only because an earlier test reset the state hides an order bug.** Run
    after a different test, it fails; run a new or suspect test alone and after its neighbours,
    and report a flake as "k fails in N runs", never as "flaky" (see 138).

140. **Sort by the parsed value, never by the raw text.** Sorting keys in mixed formats as text
    puts newer items among older ones, so a "latest" pick is wrong.

141. **A new colour key must stay distinct from every existing key after every transform the
    tool applies.** Keys distinct in their raw values can collide after a fade, tint or
    quantise, so two regions read as one.

142. **Before calling a seeded number steady, vary every seed that feeds it and measure the
    spread.** A seed group nobody varied can move the number well outside a band set from one
    seed; set any band from the measured spread (see 72 and 101). Variants that cannot move the
    number read zero spread, so include one that can (see 69).
    PRS (2026-11-07): A target gap below twice the measured noise cannot be enforced; a bound is
    set only after measuring the base.

143. **After each merge or rebase that brings in another branch, recount any count both branches
    raised by one.** The merge sees the same edit on both sides and keeps one, with no conflict,
    so the expected count falls one short of the checks that run (see 16).

144. **A mutant that stays green means a second path recovers: find it before calling the check
    weak.** Mutate both paths together to see the red; the check proves that at least one path
    works, not that the mutated one does (see 51). PRS (2026-10-26): When two fixes cover for
    each other, switch them off in steps from one saved state and score each step from its own
    result.
    PRS (2026-11-07): A later safety net (a fallback, a second pass) repairs the mutant's
    effect, so pin the step with a spy, not only the end result; prove each layer alone where it
    is the only guard, and vary the attack so the other guard cannot apply before calling a
    survivor covered; the converse too: a second path kept as a safety net is proved by mutating
    the first alone, and "X is not load-bearing" is a claim that needs a test able to see X.

145. **After a change that rebuilds the nodes, look them up again; a held reference reads a
    detached copy.** The detached node never changes, so a test holding it passes whatever the
    live page shows.

146. **A region-average check cannot see a patch edge.** A patch whose average matches its
    surroundings passes a mean check while a hard seam runs along its border; compare the jump
    across the edge with jumps inside, and prove it red on a planted hard edge (see 87 and 124).
    Feathering moves the jump inward, so measure the inner rings too (see 87).
    PRS (2026-11-07): Gate on each member or the minimum, never the average of variants; a ratio
    over a whole ring hides a consistent offset too, so measure the signed step per short run of
    the boundary.

147. Retired, see 121.

148. **A stand-in for a platform API counts only after it is compared with the platform's own
    contract.** A stub can match the real call in one behaviour and miss another (a full-write
    call that replaces the whole document); cite the contract line it was checked against.

149. Retired, see 42.

150. **Squash only onto the merge base; read the diff stat before any push.** After main moves,
    a soft reset to `origin/main` plus one commit silently reverts every newer commit on main; a
    file in the stat that the branch never touched is a revert in disguise (see 126).

151. **A tool that skips existing outputs turns a rerun into a no-op.** Move old outputs away
    (never copy them) before rerunning, or they are read as new; a run whose start and end state
    match, with no resource peak, did nothing (see 69 and 80).

## Checks that cannot fail (harvest 2026-10-26 → 2026-11-06)

*Three projects, eleven days of orchestrated rows: a game, a web app and a Windows desktop tool.
Every lesson below came from a verifier finding, a falsify run that went green where red was due,
or a human catching what the checks had passed.*

152. **A check that does not assert the count it expected runs on nothing.** A mean of zero boxes,
    a filter with nothing to filter, a scan with no hits, a test filter matching no test, a guard on
    a default that never saw a real value: each reads as a pass. Require the expected count, a
    non-default start, and a total line of at least one (see 9).

153. **A baseline that passes through the code under test is identical by construction.** A "same
    as before" row computed by the mutated function, a setup that rewrites the state after the code
    ran, or a negative pin without the precondition that the old code fails it, cannot go red. Write
    the pre-change value into the pin (see 84).

154. **A check that dereferences what the mutant removed never runs, and one that clears a cache
    before reading it cannot see what was cached.** Assert the object exists with its own check
    first; read the cache before resetting it.

155. **Pin the invariant, not today's census.** An exact set fails on legitimate growth, and a
    coverage pin that iterates a table misses a category that left the table; pair it with
    membership over the source list (see 86).

156. **A relative check against a reference passes when both sides are wrong the same way.** Pin
    one absolute number beside it (see 124).

157. **A reference in a report counts only when tied to its source.** An id that exists can be the
    wrong one, a number copied from a comment carries no commit, a SHA typed from memory is a
    placeholder, and a page's numbers need a measured source line each. Quote from the command or
    data that made it (see 58).

158. **A source-text scan pins a spelling, not a behaviour.** It stays green when the behaviour
    vanishes, goes red when a sibling refactors the shape, and misses aliases, target-typed `new`,
    comments, access modifiers and a value that contains the original as a substring. Drive the code
    and count the effect; use a scan only when nothing can be built, parsed with the language's own
    parser, as an allow-list closed in the first fix round (see 46 and 112).

159. **Measure the shipped shape.** A pin on a setting, a check on an intermediate, a tune on an
    unfinished output or a tile-level check passes while the finished result is wrong; measure what
    the user gets, with the fault planted, and keep one mutant that preserves the pinned structure
    while breaking the effect (see 119).

160. **A fit or clearance check measures the real worst case.** The longest text the code can
    build, the fullest and emptiest state, every node kind, every start state, every width, every
    phase of a motion; one typical frame passes what the user sees cut (see 122).

161. **A score the content can raise by noise or extremes is gamed.** Specks raised a detail number,
    garish looks met a distance score. Exclude the noise, prove it with a noise plant, and look at
    the output beside the number (see 90).

162. **Hash decoded pixels, never image files.** Metadata differs per render while the pixels
    match, so a file hash says "changed" for identical pictures.

163. **A number compared across sides comes from one tool and one setup on both sides.** A ratio
    mixing the builder's reader and the reviewer's measures the readers; re-measure the baseline
    with the candidate's tool (see 67).

164. **A pass line re-cut to the code's own worst run minus a margin is fitted.** The verifier
    re-derives it from fresh runs and checks it against the line registered before the build
    (see 142).

165. **A threshold set above what the rule under test can produce never fires.** Count coverage
    over what is reachable, not the full width (see 66).

166. **Check a rule over exactly the region its text names.** A wider region passes on the wrong
    part: a one-colour wall front passed on the top face's tones.

167. **A check that skips bands with too few samples hides the regression that empties them.**
    Where samples are expected, too few is a fail, and the plant empties the sample rather than
    weakening it.

168. **A census counts the pool each state actually reaches, minimum over states.** A lookup that
    prefers a variant leaves the plain pool dead, and a count of plain lines passes unreachable
    text.

169. **A sweep or pin drives the real entry point and reads the drawn result.** An inner function
    fed a hand-built copy of its inputs, a stand-in object or a source asset hides inheritance,
    moved layouts and covered nodes; cover every input the entry accepts, each side and range
    (see 105 and 119).

170. **A guard defined by the same mask or rule as the operation it checks cannot see that
    operation's leak.** Check the protected classes from an independent rule (see 74).

171. **A virtual-clock browser harness is not real time.** Stalls, unresized canvases and
    mid-animation frames appear only there; confirm a fault in real time, and settle a box-identity
    claim with two base runs or the canvases left out.

172. **A pin that drives a live scene stops its clock before acting.** Otherwise its result depends
    on host load; run such a pin twenty times under load before trusting one green (see 139).

## Mutants, REDs and gate runs

173. **A RED counts only when it fails for the predicted cause.** Read the assertion line: a parse
    error, a fixture failure, an earlier refusal or a non-test name is red for the wrong reason,
    and a green guard's reason is checked the same way (see 48).

174. **A mutant's prediction lists every check that reaches the mutated line.** Plants, other
    fixtures and each clause of a branch included, with the term that binds at the measured state
    named first; re-predict old mutants when a fixture gains checks (see 48).

175. **A battery's first run is BASE through the same driver, and any driver edit re-runs BASE.** A
    filter or scorer is run on a known red before its zero counts; reds outside the prediction are
    scored after measuring the unmutated tree's flake rate under the same build condition (see 122).

176. **Read the build line before any test count.** A test step after a failed build runs the old
    binaries and prints a real-looking pass; an incremental build reports zero warnings for what it
    did not compile; "build failed" with no compiler output is a hiccup to rerun; and a restore
    rebuilds before the next run, or the mutant's binary is what runs (see 10).

177. **Acceptance lines that hold on the pre-fix code need their own mutant.** One per kept
    behaviour and per migration path, not only per new behaviour.

178. **A fallback is proven by a plant the primary path cannot handle.** A plant the primary
    handles leaves the fallback unrun.

179. **A retry on a flake signature requires the signature to be the run's whole output.** Otherwise
    a real failure that also prints it is retried into a pass.

180. **A self-test builds its config from the parser's defaults.** One that hands the function its
    own regex never tests the run everyone uses.

181. **A positive control for a list producer checks an entry from the end.** Or that parsing
    consumed the input; first-and-middle entries pass a truncated list.

182. **A value change by find-and-replace also rewrites negative guards.** They then forbid a
    literal that never existed; keep the old literal in forbid-guards or forbid the shape, and
    mutate the old value back by another route.

183. **A focused test run is picked by blast radius, not by edited files.** Every class that loads
    what the change binds, every repo-wide scan guard, both test folders; test strings count as
    product for scans.

184. **A new or widened check runs against every open row's artifacts before either merges.**
    Otherwise whichever lands second goes red (see 143).

185. **Rebase onto main before GREEN.** A check merged after your base runs only after the rebase,
    and a gate-count prediction is main's count plus every test the branch adds over its merge
    base, counted by every test attribute the project uses.

186. **After a rebase, re-run every number the commit body quotes and amend the message only.** A
    body carried over holds stale proof (see 63).

187. **Mutants that no longer build are invisible.** Build every listed mutant in the gate or a
    census and fail on a dead anchor; a mutant harness stops when its replace did not apply
    (see 21).

188. **A record-only commit may follow the gated commit when the tree hash is unchanged.** The gate
    log at the code tip stays valid; anything that changes the tree restarts the gate (see 63).

189. **To prove a gate builds a project, plant a compile error and run the gate with a filter that
    matches no test.** The build is identical, nothing runs, and a red proves it compiles.

190. **When a script may not be run whole, cut the one block verbatim, run it in scratch, and probe
    the artifact.** Text pins miss what the block silently needs.

191. **A timeout around a job that waits on a shared lock counts the wait.** Time the work, not the
    queue (see 78).

192. **A widened check can run silent past the gate's stall watchdog.** Time it alone first and
    print its own seconds on its pass line.

193. **Print each case as it runs and count a crash as its own fail.** A summary printed at the
    end vanishes when the run dies.

194. **Bisect a slow end-to-end red by diffing the green and red logs to the failing step.** Then
    replay that step from saved state with a harness proven equal to the full check at both ends.

195. **A before/after tally uses the same population and seeds and shows where the moved outcomes
    went.** "62 of 200 to 2 of 300" was 94 to 2 at equal N, most of them moved to a neutral
    outcome.

196. **A counterfactual replay fixes the random draws per decision whatever is chosen.** One shared
    stream measures divergence, not the change (see 101).

197. **A new random draw never shares the simulation's stream.** Run the old chain on the shared
    stream, then draw from its own; a roll that skips the chain shifts every later draw.

198. **A bound checked only with the policy that respects it proves nothing.** Run the greedy
    policy that maximises what the bound limits, and the cap-removed mutant must go red there
    (see 130).

199. **Never run mutants beside your own gate.** Sequence them; a timing test went red from the
    load.

200. **A constants tune, and any claim that the gate misses a change, are proven on the full
    gate.** Not on the targeted check.

201. **An intermediate inherited from an earlier round is a new input.** Diff it against the
    accepted file over every protected region before building on it.

202. **Check a fix against the tool's own evaluated output, never your re-derivation of it.** Which
    panel actually moved on a posed frame, not the sign in the code.

## Fakes, real machines and native code

203. **Fakes match the real thing's failures and effects.** Throw as the real call throws, perform
    the destructive effect an ordering rule depends on, fill plausible output before failing,
    record every call rather than the last; and a call spy sees only calls through its seam, so
    other sites assert real state (see 148).

204. **A kill that depends on the machine proves nothing elsewhere.** A constructor reading real
    sources before the test switches them off, or a guard whose verdict depends on what is
    installed: set a value, then remove the source, and count the real calls with a positive
    control (see 139).

205. **A safety property the test seam stubs away has no guard.** File share modes, map rights:
    mutate each, and pin the survivor.

206. **A mutant that removes a safety guard is stacked with a stub of the side effect and a safety
    net that stays.** It fails toward a temp place, never the real target, runs only the tests that
    cannot write, and a probe that plants binaries starts the child with loader errors silenced.

207. **A guard that makes real defaults throw in tests un-pins what those defaults chose.** Re-pin
    each choice through a seam that takes the refused value, and verify a named stopper with a
    test-owned input, not an environment fact.

208. **SEVERE: a test or probe that can reach a real path injects and pins every one in the module
    initializer.** Every probe class sets them itself whatever the run-wide pins, the real file is
    backed up before the first run, and the real folders are measured before and after (see 14).

209. **A guard on a place by the spelling of its path is bypassed by another spelling.** Doubled
    separators, device prefixes, short names, streams, aliases; refuse shapes outside an
    allow-list, compare identity (the final path by handle), refuse a root that contains the real
    folder, and cover every file the writer really opens, temp siblings included (see 65).

210. **An elevated step over a user-writable tree follows junctions and keeps old handles'
    rights.** Work handle-relative on a fresh object created with its final rights; never re-check
    and reuse.

211. **Native interop: each struct layout gets its own size and offset guard.** A real-path test
    tells a thrown or status fault apart from "source absent" with an independent oracle, and a
    fault record survives every early return.

212. **An event raised during a constructor's own first work fires before any listener exists.** A
    "first seen" pattern snapshots after subscribing, and its test makes the source ready before
    construction.

213. **A create-once named object that a long-lived reader holds open outlives its creator.**
    "Already exists means fatal" then blocks the creator's restart; test restart with the reader
    attached.

214. **A rollback is tested by failing every step after the point of no return, the last
    included.** Fakes hold what the real thing holds (a started service locks its file);
    irreversible steps run last, and what they overwrite is snapshotted first.

215. **Anything parallel tests write in common is written under one lock or per test.** And read
    with shared access; one dropped line turned an unrelated test red.

216. **Each fixture instance gets a unique name and deletes exactly that.** A fixed name deletes a
    leftover the human's machine kept, and names differing only by case are one folder on a
    case-insensitive disk.

217. **A source file compiled into two assemblies needs a mutant per assembly.** One mutant changes
    both copies at once and cannot show that each has its own pin.

218. **An approved list of what code may write is rebuilt from every layer's source.** The driven
    module included: one call the caller cannot gate wrote hundreds of registers.

219. **A guard that keeps private tokens out of a public repo stores only their hashes.**

## Data, UI and shared state

220. **A hold flag shared by several editors is a count or tied to the open editor.** A bool any
    editor's end clears is cleared by the wrong one.

221. **A whole-document replace drops fields the index orders on, and the record vanishes from
    queries.** A stub that sorts but never drops cannot see it (see 148).

222. **A once-only guard kept in a tab or process is per copy.** Claim the action in the shared
    store with a lease and re-read before acting.

223. **A status derived from a link field drifts when any writer repoints the link.** List every
    writer of the key before trusting the derivation.

224. **When a callee can substitute the requested action, cost and legality checks run on the
    action performed.**

225. **A UI target handed to another layer must be connected, displayed and non-zero in size.** A
    hidden empty anchor accepts the wiring and freezes the feature.

226. **A change to shared code is tried on one frozen artifact that still loads it.** No fixture
    covers the archive.

227. **A fix that rounds or reformats an input moves every figure derived from it.** Compare
    derived outputs to base with values outside the new format.

228. **A control that compares whole-state snapshots runs from fresh state.** Every snapshot after
    the first intended difference carries it.

229. **For each text-scan RED, name one wrong fix that would pass it.** Widen until it refuses the
    same fix written another way, and check a review's own fix idea against its REDs (see 9).

230. **Raising the top of an enum: grep every comparison to the old top value.** Not only the
    readers of the field.

231. **An inserted comment goes at the end of a line.** Mid-line it comments out the rest of the
    statement.

232. **When replacing a component, find its users by behaviour, not only by path.** Methods,
    signals, focus; a path grep missed a screen.

## Git, shells and the machine

233. **`--amend` rewrites whatever HEAD is now.** After a conflicted `rebase --continue` that is the
    last replayed commit; after a failed `&&` chain it is the previous commit. Check `git log -1`
    before any amend; repair with `commit-tree` on the same trees.

234. **When your base branch was itself rebased, move your row with `rebase --onto`.** A plain
    rebase replays the old base commits (see 126).

235. **`git commit -- <path>` commits the working file and ignores a staged blob.** To commit a
    version that differs from the working file, stage it and commit with no pathspec, then check
    `git show HEAD:<path>`.

236. **In a generated-file conflict, `checkout --ours` drops the other side's auto-merged hunks.**
    Resolve the conflict hunk only, regenerate, and prove the non-generated diff equals the
    branch's own.

237. **After rebasing onto a sibling's fix of the same thing, run the sibling's committed tests
    unchanged against the merged code.** Remove none.

238. **Before resetting a shared file to an older version, list the commits it undoes.** Carry
    forward each one that is not the mistake (see 23).

239. **Record the base SHA when the worktree is made and use it for every base run.** `origin/main`
    moves as siblings fetch, and a base gate on a newer commit reads as a lost-test regression.

240. **A commit or merge message states its scope from `git diff --stat`.** Never from a
    description; "board only" carried twenty-two files.

241. **SEVERE: every destructive command names an absolute path and is never chained after a `cd`
    with `;`.** A failed `cd` ran `rm -rf .git` in the repo root; scratch harnesses make a fresh
    folder per run; a repo with no remote gets a scheduled bundle.

242. **Never match your own command line.** `pkill -f` or `pgrep -f` with a pattern that sits in the
    same command kills or waits on the calling shell; list pids in one call and act in the next,
    or bracket the pattern.

243. **Never remove the folder your shell stands in.** Every later spawn fails until the next `cd`.

244. **A background job started inside one tool call dies when the call returns, and `&` under the
    tool's own background mode orphans it.** Use the background mode alone, or `setsid`/`nohup`
    for a long gate.

245. **Never SIGSTOP a run under `timeout`.** The wall clock keeps counting and the run is a
    non-result; pause by starting nothing new.

246. **Write scripts and evidence with a quoted heredoc or the file tool, and syntax-check them
    before use.** An unquoted heredoc runs backtick spans and eats backslashes; a tool parameter
    decodes JSON escapes, so a literal backslash sequence is built in a script, never typed.

247. **A scripted edit asserts every anchor matched exactly once and that each line changed, then
    writes once.** A missed anchor leaves a commit claiming an edit that never happened (see 23).

248. **A liveness check by pid also checks the process name.** Pids are reused within minutes.

249. **Scratch on a shared tmpfs fills from every session at once and stops all of them.** Evidence
    goes on the real disk, and a dead-session sweep checks open handles, not file ages.

250. **Every landing path removes the row's worktree and trims its scratch to text.** Nothing else
    does, and copies pile up by the dozen; a "done" test by ancestry also passes a brand-new
    branch, so a cleanup asks "own commits? fresh? untracked?" and applies only the approved list
    from the same scan; a copy made inside a row's folder refreshes its age (see 4).

251. **Sessions are identified by name and repo.** A host running two projects shares names, so a
    launcher matching by name alone skips a lane or counts the other team.

252. **Evidence paths include the project.** Two seats sharing a row prefix write into one folder,
    and a verifier reads the other project's files.

253. **Rules by path load only for files under the session's own folder.** A builder launched in
    the main checkout editing a sibling worktree never sees them; start builders in their worktree.

## Seat, briefs and the human

254. **Every time stamp comes from the clock inside the command that writes it.** Board, brief,
    evidence and message times typed from an estimate were wrong by up to forty-five minutes and
    read as fact; a relayed time gets the same check.

255. **A rule that lives only in a memory note is rediscovered after it breaks.** A rule a session
    must follow goes into the skill it runs; a rule about a made thing into the tool that makes
    it; when a ruling replaces a rule, every text that states it changes in one commit (see 57).

256. **A procedure moved from an always-read text into an open-on-that-step how-to keeps a trigger
    at a step the reader already meets.** Or it stops happening: a nightly backup stalled unseen
    for a week.

257. **Fields a tool reads from the board are carried forward at every rewrite.** A banner rewrite
    that drops the live-version line blanks the display for days.

258. **A brief's own text is run against the project's rules and guards before it goes out.** A
    brief that bans a word and quotes it contradicts itself; a ruling on a review finding is
    checked against what the vendored API can do; the gate is named as it exists on the row's
    base, not after an unmerged row.

259. **When a design needs what a guard bans, narrow the guard to the one approved site.** Pin that
    site by identifier, add a second-site mutant, name the loosened guard in GREEN-FINAL, and name
    every other row's guard on the same thing in the brief; rulings that clash show only at merge.

260. **A mechanism tagged guessed goes into a brief as an option to measure.** What a brief carries
    safely from a verifier or builder is the symptom and the harness, never the prescribed shape.

261. **A ruling or brief that changes a value an invariant pins is checked against the requirements
    list first.** The population table lists, per item, the invariants it touches.

262. **Measure a ruling's literal effect on the real population before building it.** Taken at its
    word it changed thousands of cases where the target was a hundred.

263. **Before accepting a narrowed scope, re-read the goal's quantifier.** "Every" and "all" against
    the list of what the builder is not touching (see 42).

264. **A population line is marked read or run.** No fix is planned until its RED is red; a
    "present" read from code was not a defect.

265. **A screen described in words gets one still picture of the layout approved before the
    build.** Rules alone built the wrong screen three rounds running.

266. **A feature is done only when a fresh user sees a real value with no manual step.** A
    placeholder pending a script is not done.

267. **Visible changes the human did not ask for are listed and shown before landing.** A review
    recommendation that departs from a decided layout included.

268. **A human ruling given in chat is written to the decisions list the same turn.** Otherwise it
    is re-asked the next day.

269. **A question to the human stands alone.** What it is in plain words, what it settles, the
    options with their effect, a recommendation, and what happens if they say nothing; prefer
    deciding with the default stated.

270. **Check a third-party file's licence before recommending to ship it.** Say the result in the
    same message.

271. **A hand-over file goes where the human actually looks.** Resolve their folder; three sessions
    copied to one he never opens.

272. **An instruction to the user is traced down the path they will take.** Including the state the
    UI shows there: a box the text named was unticked on that path.

273. **A doc that states facts is source-checked claim by claim by a session that did not write
    it.** Help text and hints too: a hint naming a rule's effect is a claim, a page's statement
    about the code is grepped before it is filed, and you open the page yourself before telling
    the owner what it says.

274. **A session recycled mid-row gets the handover, not the original brief alone.** What passed
    and where the state is; otherwise it restarts step 1.

275. **A validator is relaunched with a READ marker, never the builder brief.** The brief reads as a
    build order (see 34).

276. **A lane you wait on is watched.** Subscribe to its idle notice and check its verdict file; a
    sibling can die mid-row with no message, and a turn that ends on "next I will" with no tool
    call sits idle until someone asks (see 36).

277. **Before a large review, a lane checks its fill against the handover mark and says so.**

278. **The verifier recomputes agreed numbers with its own script.** A builder's check exiting 0
    proves only its own definition; a census that reuses the guard's rules inherits its blind
    spots; a verifier's own findings are traced to the value they change and their citations
    re-grepped before sending (see 7).

279. **A READ of a review row rebuilds one area's population from scratch.** And re-tests every
    item marked real for staleness and mis-matching; checking the claims found less than
    rebuilding (see 42).

280. **A "no behaviour change except X" claim is rebuilt from every product hunk by the verifier.**
    And an approved scope widening is read for side effects on every consumer of what it changes.

281. **A verification report states per step what actually ran.** Re-checked, rebuilt, parse only,
    not run; every count derives from that table, limits raised by hand are counted, and a bound
    equal to a sample's own max is not a check (see 49).

282. **A merge trial uses main as it is at trial time.** Check whether it moved since the seat's
    message; a train audit compares each READ's trial base with the landed merge's first parent.

283. **A screenshot is evidence only after its fixture is checked against what the code reads.** One
    control per view; a hand-built fixture was the "bug".

284. **Before moving or archiving files, grep every open row's scripts and briefs for their
    names.** Another row reads them.

285. **Read the shared tool index before writing a helper.** Hand-written mutant runners and scorers
    miscounted reds three times; the shared tool had already solved it.

286. **A version bump greps every spelling of the old version.**

287. **Code is done only after one run on real input.** A change marked done from the edit crashed
    on first use.

## Submitted (not yet cleaned)

Last clean: 2026-11-07

A session that learned a lesson appends one line here the same day:
`- <the rule>. Why: <what goes wrong without it>. Case: <date>, <row or area>.`
No project names, folders or people. Once a week the `lessons-clean` skill turns these lines into
numbered lessons above (or one marked addition to an existing lesson), empties this list and moves
the date.

- A check that counts distinct levels (colours, bands, buckets) must also cap the share left outside the counted levels. Why: a smooth ramp still shows N big clusters plus a long thin tail, so a cluster count alone passes the very gradient it should refuse. Case: 2026-11-08, toon shader band guard.
- Sessions launched with `--model opus[1m]` read their window as 200K from the model string (it carries no [1m] suffix) and asked for recycles at 115-180K; the launch flags in `ps` decide the window, so READY and orient should report the launch flag and ctx-fill should default to the team block's window, never the model string (2026-11-08).
- A session reads its own context window from its launch command (`--model opus[1m]` in `ps` / `/proc/<pid>/cmdline`), never from the model id in its env block, before it passes `--window` to ctx-fill or refuses work at a mark. Why: the env block can name the bare model id for a 1M launch; a verifier read 200K from it, declared itself past handover at 156K and refused a READ it had room for.
- A level-count image guard that merges adjacent levels into clusters passes a smooth gradient as one wide "level"; cap each cluster's width, and run a gradient mutant before trusting it.
- A probe takes its expected value (scale, rate, limit) from an independent source, never from the thing under test: a foot-slide probe that read leg length from the skeleton it was checking scored the unfitted mutant the same as the good body, because the mutant carried its own matching scale. Falsify with a mutant whose own measurement is consistent but wrong before trusting the probe.
- When the gate runs headless, a shader-driven feature needs its test written twice: a script twin of the shader logic that the pin measures geometrically, and a one-time render cross-check (flat ID colour, on/off) that also catches a shader-only mutant. Why: the pin otherwise stays green while the shader drifts, since a headless run never compiles or draws it. Case: 2026-11-08, iso wall cutaway.
- A probe that samples an animated pose must also prove the pose it read actually moved (one part travels a set distance from rest): engines that apply pose modifiers in a late pass can hand a reader the rest pose, and every length/angle check then passes on a still figure.
- A check whose reference is rebuilt with the same step it is checking (a fold check against a "reference" made by the same seam merge, a shading check that only asks that normal deltas are non-zero) cannot fail on that step; build the reference from the approved original and measure the effect (recomputed normals vs exported, turned faces vs the pre-change shape), with the original's own noise floor as the bar.
- A source-text check that looks for its expected lines in order (substring find plus a return count) passes an inserted statement between them, so it does not prove "the same code": compare the whole normalised function body for equality, and mutate with an insertion, not only a replacement.
- A merge-prep rebase of a branch that its builder or a verifier still has checked out goes on a NEW branch made from the approved tip (`git worktree add -b <row>/merge-prep <dir> <tip>`), never on the original. Why: git refuses a second checkout of a checked-out branch, and moving the ref under a running READ changes what the verifier reads. Case: 2026-11-08, a vendored-addon row rebased for merge while its READ ran.
- A check that only runs by hand cannot fail where it matters: when the gate runs no interpreter the check needs (a Blender-only guard), split the logic so it runs on saved arrays in the plain interpreter and add it to the gate as one counted line, rather than shipping a by-hand command.
- A seat ruling that sets a numeric target from a legacy constant (a scene speed) must be checked against the geometry it drives before the go: planted feet at the old 1.78 m/cycle turned a walk into a lunge that the old foot slide had hidden.
- A builder that hands work to its own subagent must not start a gate in the same worktree until that subagent has stopped: a gate started right after a resume snapshots its half-edited tree (dirty=N) and its red lines read like real regressions; check the `dirty=` on the gate's started line before trusting any result.
- A numeric pin that reads an effect's size from the node itself (its scale, a uniform) can stay green while the renderer ignores that value (a billboard material drops the node's scale unless told to keep it): look at one render of every new visual effect before trusting the pin, then pin the setting that carries the value to the screen.
- A mutant that deletes the only statement in a block (the body of an `if`) is a parse error, not a red: the run proves nothing about the check. Replace the statement with a no-op (`pass`) so the mutant builds, and treat any SCRIPT ERROR in a mutant log as an invalid mutant.
- A verifier mutates a pipeline step by feeding the pipeline's own pre-step artifact (the build output before the fix step) to every check, and a check that prints a failing table but exits 0 counts as no check; likewise an engine setting is verified by rendering two values of it, never by reading it back (an orthographic camera silently ignored a shadow-distance cap while the pin read the stored 25 m).
- A contact or seam metric that takes the closer of two surfaces per pose counts a part sweeping past as a jump (a jaw passing over the neck read 12.7 mm while the real surface moved 0.7): fix each sample point's surface at rest, then measure motion against that surface only.
- A verifier mutates the ruled VALUE, not only the code path: a pin whose expected number is computed from the same knob it guards stays green when that knob drifts; and an integrity seal over a record must cover every field the consumer reads (a seal over the inputs the guard judged, but not the arrays the writer builds from, lets a post-guard edit through under a valid seal).
- An "exact" oracle a test or verifier compares a measurement against must use the measured code's own reference points and thresholds: an oracle that anchors its cut-off line on a slightly different reference moves the line with it and can hide a systematic error on every input (a chin finder read up to 4 mm lenient on all 110 bodies while its test's oracle agreed within 0.03 mm). Rebuild the oracle from the code's own anchors and check where its minimum lies (on a boundary = an interpolation gap).
- A gate that pins time (fixed frame rate, frozen clock) hides tests that depend on frame timing: a test can be green in every gate and red 15 times in 20 alone on a busy host. Run each new timing-sensitive test standalone, without the gate's timing flags, ~20 times under load before trusting it. (2026-11-08)
- When a rule combines two measurement methods (min, agreement), preview a proposed change on every method before quoting its cost: a preview on one method that happened to be insensitive reported "free", and the change built into both failed a dozen cases.
- A command a hook or guard blocks runs none of its parts: a heredoc file it would have written does not exist, so a retry that reads that file fails after the half that did run (a soft reset with no commit message). Write needed files in their own call before the guarded command.
- A mutant that removes ONE of two redundant safeguards proves nothing (it stays green); to show a guard catches the defect, rebuild the old faulty pattern in full (remove every safeguard), and write the redundancy into the prediction before the run
- A pin must reach the code path the product uses by default: a pin that passes the option it guards as an explicit argument stays green when the default flips to the old route. Call the entry the way production calls it, assert which route it took, and keep the explicit-argument call only for the counter-case. Separately, a geometric sign or projection taken from a moving reference frame (a bone line, a camera axis) changes under rigid motion of both sides; sign a distance by the closest surface's own normal.
- A check that loops over a list (poses, stages, cases) must also check the list's length: cut to 0 or 1 entries, every loop finds nothing wrong and passes, and when several checks share the list one cut empties them all; mutate the list (empty, one short) and expect red.
- A session launched with a 1M-window model alias can show only the bare model id in its env block: three fresh siblings in one seat read "no [1m]" as a 200K window and asked for relaunches. The seat states the window in the banner from the launch flag (the recycle script's summary prints it), and a session never lowers its window from the env block alone. (2026-11-08)
- When a guard or check tightens, rerun it on every artifact the in-flight rows produce before merging them: two rows each green on their own base (a stricter hole rule; a new body with an open neck seam) merged into a pair where the guard refuses every body, found only by a later row's population. (2026-11-08)
- A threshold applied to sampled points (mesh rings, cut points, frames) acts in steps: a mutant that moves it stays green unless some sample sits between the old and new edge, so pick or build the fixture by where its samples lie on BOTH sides of the edge, and say in the pin which sample it relies on (a guard band 6 -> 9 mm stayed green on every test body because each had one ring inside the band and none just outside).
- A check that compares a candidate file against a reference file must pin the reference itself (a content hash) and refuse a reference that is the candidate: without that, pointing the reference at the candidate, or copying the candidate over the reference, compares the file with itself and passes; a separate check on the reference that only reads names or counts does not catch it.
- A test must hold its expected cases itself, never derive them from the constant it guards: planted cases built from the module's own list (forbidden tokens, ruled values) shrink with it, so a dropped entry stays green; a falsify mutant that removes one entry is the check (seen 2026-11-08 on a name-scan test).
- Compute small angles (rotation match checks, normal deviation) in float64 as atan2(|skew part|, (trace - 1)/2), never as 2*acos(w) of a float32 quaternion: the float32 form reads every angle under ~0.03 deg as exactly 0, so a 0.05 deg tolerance looks clean when it is unmeasured; a reading of exactly 0.000000 on noisy data is the tell.
- A verifier told mid-READ that its row moved to another verifier replies first with how far it is (gate running, evidence folder, no verdict sent) and lets the seat pick: a fresh seat reassigns from the handover text, which lists rows as queued, not from the verifier's progress, so a silent stop throws away a near-finished READ and a second reader may find the first one's evidence; the seat reversed its move once told (2026-11-08).
- A "waits for someone else's lock" test (start it, kill it, check nothing was written) must also prove the subject reached the wait (its waiting line in the log): a wrapper that dies early on an unrelated check writes nothing and passes; and every stubbed run must get the test's own config path explicitly, or it silently reads the machine's real settings and writes to real folders while its checks look at the test folder.
- A "weld within d" built by rounding to a d-grid (np.round(V / d) + unique) is not a distance weld: twins far closer than d that straddle a grid line stay apart, and a test fed exact copies cannot see it. Weld by true distance (cells only propose pairs), and test it with near-twins placed across a cell line plus a pair just over d in diagonal neighbouring cells.
- A lint that pins every call of a sensitive API by AST must, from its first round, resolve aliases, from-imports and attribute paths, and REPORT what it cannot follow (the module used as a value, a store into it, exec/eval, a run-time module load) instead of passing it; it must also cover calls outside the files that look like the risky case: a verifier found each of these as a green bypass across two fix rounds.
- A seat that edits its board and reassigns a READ checks first how far the current verifier is, and runs every board write under `set -e` (guard && edit && commit): a newline after a failed guard commits nothing while the assignment messages still go out, so the board silently loses rows the team is working.
- A test that sets an identity variable for every run it starts (session name, user, owner) never exercises the default used when that variable is unset, which is how every real session runs: give each such check at least one case with the variable unset (two runs at once that must not share the default).
- A verifier tool that rebuilds its own mesh/object before calling a shared guard must carry every input the guard reads from the original (names, metadata, flags), or the guard silently skips that check while still printing PASS: falsify a new guard wrapper with a planted case for EACH check inside the guard, not only the one the row is about. Also: never apply a code mutant in a tree that another of your own background jobs will read later; mutate in a separate tree or wait for that job.
- A tool that records a "ground truth" from a fresh instance (a pose, a state, an output) and then checks itself against that record proves only its own copying: a READ must drive the real runtime sequence (what ran before, blends, history) and compare, and the record step needs its own check that it holds the asked-for state (a recorder that silently captured the default state passed every match). A tolerance merge (weld, dedupe, cluster) that is transitive can chain: cap the group's total span, not just the pair distance.
- A checked-in count (expected test lines, a version, a total) that both a branch and main raised to the same number merges or rebases with NO conflict and stays one short: after every rebase or merge, recompute it from the base plus this branch's own additions and set it by hand; never trust a clean merge of a count line.
- A mutation run on an extracted copy of part of a tree (to keep the worktree clean) first needs the PRISTINE extracted copy run as its own baseline: a file the extract left out (a sibling folder a script copies from), or a stand-in process that dies before a long wait ends, fails the same cases in every mutant and hides which case each mutant really turned red; a test that holds a live process for a stale/refuse case gives it a lifetime longer than every wait it must outlast, and a short wait limit so a wrong "alive" judgement fails fast.
- A test that a cost bound holds (a crafted input that used to blow up time or memory) must run that input in a child process with a wall timeout and an address-space cap (RLIMIT_AS in the child), so the unbounded code fails the test in seconds instead of exhausting the machine; a timer inside the same process cannot stop a native call mid-way.
- A static pin that only checks call sites in files matching a trigger list ("files that join", "files that import X") misses every equivalent shape outside the list (another builder call, an alias, a wrapper module, a store into the guarded module, exec of a string): drop the trigger and require every call site to pass the rule or carry a written reason in an allow list that fails on stale entries, then falsify it with a battery of in-memory planted files (one per shape) before calling it closed.
- A before/after picture check whose "allowed change area" is built from rest-pose (undeformed) positions flags real changes as stray when deformers (shape keys, skinning) move the changed faces: build the area from the drawn (deformed) positions of every face touching a changed vertex, position OR normal (smooth normals carry a change one face further). Provenance: a picture-diff row, 2026-11-08.
- A `mkdir` lock is only atomic if the coreutils make it so: on uutils coreutils 0.10 many concurrent `mkdir` calls of one path all succeed (169/200 measured), so a mkdir mutex let two runs into one folder; take shell mutexes with noclobber `(set -C; : > f)` (O_EXCL in the kernel) and stress-test any lock with N concurrent takers before trusting it.
- A dataset that later verifications reuse (a population of dumped inputs every READ diffs against) must not live only in the scratch row of the task that made it: scratch is evidence on a cleanup clock (here: non-text files stripped 3 days after the last write), so the first quiet week deletes the baseline. Copy it to a durable data folder with checksums and a README naming its source and users, and point the memory notes there.
- Before routing a fix for a measured body or model deviation, measure the same landmark on the bare base and with each modifier (shape key, pose, layer) applied alone: the deviation can come entirely from one modifier while the base is fine, and a fix aimed at the base (bones, proportions) would then be wrong. Found when a 'long neck' turned out to be one shape key sinking the shoulders 4 cm on a base that already matched the reference.
- Never write a note, doc or message that holds backticked commands through an UNQUOTED heredoc (`<<EOF`, or `python3 - <<EOF` with shell vars in it): the shell runs every `command` inside it as command substitution while writing the file. Quote the delimiter (`<<'EOF'`) and pass variables as arguments, or use the file tool (a handover note silently started the full gate and an unrelated tool run; the text kept empty holes where the commands were).
- Before building the output a runtime will load, check which input variant that runtime is verified on (its pin or test names the file), not which one the build tool defaults to: two same-mesh variants can differ exactly where the runtime needs them (one re-cut to stay fold-free when blended, one not), and a build on the default passes every build-side check.
- A verifier's stress or fuzz harness runs under hard bounds from its first run (`ulimit -v` of a few GB plus `timeout`, one case per process): a generated input can grow exponentially while it is BUILT (re-escaping a string per nesting level doubles it each time), and one unbounded run took the shared machine out of memory and killed other sessions' jobs before the code under test ever saw the input.
- A stress test for a lock or takeover guard counts the winners per contended round (e.g. "exactly one takeover message"), not only overlaps of the protected work: a non-exclusive guard (mkdir on some coreutils) gave two or three winners in 10-13 of 80 rounds while a real overlap showed in 0 of 80, so an overlap-only test would have passed it.
- A "no worse than before" check on a COUNT (sharp edges, warnings, failures <= the original) passes while new defects appear wherever the change also removed old ones: compare item by item and count only the NEW ones (worse than both the before state and the base), next to the total. (11-09: a blend mask cut old folds and made new +70 deg creases; the total still fell.)
