# OpenShift Serverless skills

**Reserved — no skills here yet.** This directory marks `serverless` as a product area in
this repo so the first contribution has an obvious home.

OpenShift Serverless (Knative Serving and Eventing) skills belong here, as `skills/serverless/<skill-name>/`.

## Likely first skills

- Serving: Service/Revision/Route traffic splitting, scale-to-zero and cold starts, autoscaling (KPA vs HPA), revision garbage collection
- Eventing: Broker/Trigger wiring, Channel and Subscription delivery, dead-letter sinks, source health (PingSource, ApiServerSource, Kafka)
- Diagnosing a Revision that never becomes Ready, or traffic that does not shift

## Contributing

Read **[docs/adding-a-skill.md](../../docs/adding-a-skill.md)** first. The short version:

- A skill is `skills/serverless/<skill-name>/SKILL.md` plus `references/` and `evals/`.
- **Evals are required, and the bar is specific.** Expectations must be able to tell a
  correct answer from a merely plausible one. The guide explains what that means and
  shows the ways we got it wrong.
- Every skill is measured against an unaided baseline on the same prompts. A score with
  no baseline is not a result.

## Schemas

`make test-expectations` validates any `spec.*` path your expectations assert against
committed CRD schemas. Until `skills/serverless/_schemas/` exists, your paths are reported
as **unvalidated** rather than failed — so the guard will not block you, but it also
will not catch an expectation that grades for a field the API would reject. Adding the
schemas is worth it early.

There is deliberately no `SKILL.md` in this directory: a placeholder skill would be
discovered by `npx skills add` and installed by everyone.
