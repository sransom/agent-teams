# Plan templates

Drop-in starter templates for `/spawn`'s create-new-plan flow. When `/spawn`
needs to scaffold a plan and finds one of these in the target directory (or
a parent), it copies the template into the new plan path and substitutes
placeholders instead of using its built-in skeleton.

## Files

| File                              | When to use                                                                   |
|-----------------------------------|-------------------------------------------------------------------------------|
| `TEMPLATE.md`                     | Single-milestone work — one feature, 3-7 checkboxes, one implementer.         |
| `multi-milestone-TEMPLATE.md`     | Multi-arm work for `mol-plan-driven-team` — 2+ parallel arms with file boundaries. |

Pick the simpler one unless you actually have parallel arms. The
multi-milestone template's Arms section is overhead if you don't need it.

## How `/spawn` discovers templates

When you run `/spawn` and there is no existing plan, the wizard:

1. Picks a plans directory (first match): `./docs/plans/`, `./plans/`,
   `~/.claude/plans/`, or asks you.
2. Looks for a template **in that directory first, then walks up parent
   directories until it hits the repo root or your home directory**:

   ```bash
   ls TEMPLATE.md _template.md .template.md *template*.md 2>/dev/null
   ```

3. If multiple files match, the precedence is:
   1. `TEMPLATE.md`
   2. `_template.md`
   3. `.template.md`
   4. First `*template*.md` alphabetically
4. If a template is found, `/spawn` copies it to `{name}.md` and runs
   placeholder substitution (see below).
5. If no template is found, `/spawn` falls back to its built-in scaffold —
   roughly the same shape as `TEMPLATE.md` but with no comment-block
   prompts inside the sections.

## Placeholder substitution

`/spawn` performs a simple text substitution on the copied template:

| Placeholder    | Substituted with                                          |
|----------------|-----------------------------------------------------------|
| `{{name}}`     | The kebab-case plan name (e.g. `auth-refactor`).          |
| `{{feature}}`  | The `feature` var (free-text feature description). Falls back to `{{name}}` if `feature` isn't set yet. |
| `{{date}}`     | Today's date in `YYYY-MM-DD` format.                      |

Substitution is plain string replace — no Mustache, no Jinja, no escaping.
If you literally need `{{name}}` to appear in the rendered plan, write
`{{ name }}` with spaces or `\{\{name\}\}` and edit after substitution.

After substitution, `/spawn` reports:

```
Copied template from {template-path} → {new-plan-path}
```

Then it stops the wizard and tells you to fill in the plan and re-run with
`--from-plan {new-plan-path}`. It does NOT pour a molecule against an empty
template.

## Drop into a consuming repo

These templates live in `agent-teams` so you can vendor them into your own
repos. There are three common placements; pick whichever matches your
existing layout.

### Single-milestone, repo-wide default

```bash
# From the consuming repo's root:
mkdir -p docs/plans
cp ~/path/to/agent-teams/examples/plan-templates/TEMPLATE.md docs/plans/TEMPLATE.md
```

Now `/spawn` will use this template for every new plan in `docs/plans/`.

### Multi-milestone default

```bash
mkdir -p docs/plans
cp ~/path/to/agent-teams/examples/plan-templates/multi-milestone-TEMPLATE.md \
   docs/plans/TEMPLATE.md
```

Same as above, but the multi-milestone template wins because the file is
named `TEMPLATE.md`. Use this when most of your plans go through
`mol-plan-driven-team`.

### Both, side-by-side

```bash
mkdir -p docs/plans
cp ~/path/to/agent-teams/examples/plan-templates/TEMPLATE.md \
   docs/plans/TEMPLATE.md
cp ~/path/to/agent-teams/examples/plan-templates/multi-milestone-TEMPLATE.md \
   docs/plans/multi-milestone-TEMPLATE.md
```

`/spawn` picks `TEMPLATE.md` by default (single-milestone). When you want
the multi-milestone shape, copy it manually:

```bash
cp docs/plans/multi-milestone-TEMPLATE.md docs/plans/{your-plan-name}.md
# then edit, substituting {{name}}, {{feature}}, {{date}} yourself
```

### Global default for all repos

```bash
mkdir -p ~/.claude/plans
cp ~/path/to/agent-teams/examples/plan-templates/TEMPLATE.md \
   ~/.claude/plans/TEMPLATE.md
```

`/spawn` walks parents up to `$HOME`, so any repo without its own
`docs/plans/TEMPLATE.md` will fall back to this one.

## Editing the templates

Both files are plain markdown. Edit in place. The HTML comment blocks
(`<!-- … -->`) are author guidance — leave them in your repo's copy so
your team gets the prompts when starting a new plan, or strip them out
if you find them noisy. They don't affect rendering on GitHub or in
most markdown viewers.
