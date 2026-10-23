# OpenShift Pipelines skills

**Reserved — no skills here yet.** This directory marks `pipelines` as a product area in
this repo so the first contribution has an obvious home.

OpenShift Pipelines (Tekton) skills belong here, as `skills/pipelines/<skill-name>/`.

## Likely first skills

- PipelineRun and TaskRun failure triage: step exit codes, the ordering of init containers, workspace and volume binding
- Resource plumbing: Workspaces, results passing between tasks, matrix fan-out
- Triggers: EventListener, TriggerBinding and TriggerTemplate not firing

## Contributing

Read **[docs/adding-a-skill.md](../../docs/adding-a-skill.md)** first. The short version:

- A skill is `skills/pipelines/<skill-name>/SKILL.md` plus `references/` and `evals/`.
- **Evals are required, and the bar is specific.** Expectations must be able to tell a
  correct answer from a merely plausible one. The guide explains what that means and
  shows the ways we got it wrong.
- Every skill is measured against an unaided baseline on the same prompts. A score with
  no baseline is not a result.

## Schemas

`make test-expectations` validates any `spec.*` path your expectations assert against
committed CRD schemas. Until `skills/pipelines/_schemas/` exists, your paths are reported
as **unvalidated** rather than failed — so the guard will not block you, but it also
will not catch an expectation that grades for a field the API would reject. Adding the
schemas is worth it early.

There is deliberately no `SKILL.md` in this directory: a placeholder skill would be
discovered by `npx skills add` and installed by everyone.
