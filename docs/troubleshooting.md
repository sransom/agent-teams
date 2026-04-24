# Troubleshooting

Common issues and fixes when running agent-teams. Add new entries as they come up.

---

### "Agent type 'X' not found" after installing

Claude Code snapshots the registered agent list at session start. Newly installed agents (including the five shipped here) won't appear until you **restart Claude Code**. Close the current session and start a new one.

### "formula 'X' not found" when running `bd mol bond`

beads' `bd mol bond` command only resolves formula names that start with `mol-`. All shipped formulas use this convention (`mol-full-team`, `mol-implement-arm`, etc.). If you're writing custom formulas and want them usable with `bd mol bond`, prefix the filename with `mol-`. See `docs/writing-formulas.md`.

### Arm B's lint fails with "cannot find module '@/lib/foo'"

Arm B depends on a file that arm A creates, but B's worktree was branched off `main` before A landed. Merge A's branch into B's worktree before dispatching B:

```bash
cd /path/to/{team}-impl-{arm-b}
git merge agent/{team}/impl-{arm-a} --no-edit
```

If the merge conflicts, that's a real decomposition problem — re-think the arm boundaries.

### Judge returns ready immediately (before arms close)

beads doesn't enforce `waits_for: all-children` automatically — it's a declaration the orchestrator reads and acts on. The orchestrator should dispatch the explorer first, execute its bond commands, dispatch the arms by ID, wait for them to close, then claim the judge. See `commands/spawn.md` Step 5.

### Test runner (vitest) not installed at project root after test-writer runs

The test-writer installs vitest in its own worktree. When the orchestrator merges the test-writer branch into `integration/{team}` and then into `main`, the package.json + pnpm-lock.yaml changes come along, but `node_modules/` does NOT. Run `pnpm install` (or `npm install`) at the project root after merging test-writer's branch — the integrate step should do this automatically. If `npm run build` fails with `Cannot find module 'vitest/config'`, that's the symptom.

### Codex CLI rejects `gpt-4o-mini` with a 400 error

Some Codex CLI installs only accept the model their current subscription allows. If `gpt-4o-mini` fails, try `gpt-5-mini` or `gpt-5.4-mini`. The codex-reviewer step in our formulas uses `gpt-4o-mini` by default, but it's informational only — failure there doesn't block integration.

### `--local` install issues

<!-- Populate as issues arise. Likely entries: uninstall --local symmetry, formula override resolution order, version-stamp drift after upgrade. -->

(No reports yet. Add an entry here when one comes up.)
