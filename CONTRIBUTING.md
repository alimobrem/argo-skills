# Contributing to Argo Agent Skills

Thank you for your interest in contributing! This document provides guidelines
for contributing to this project.

## How to Contribute

### Reporting Issues

- Use [GitHub Issues](https://github.com/alimobrem/argo-skills/issues) to report bugs or suggest features
- Include the skill name, agent platform (Claude Code, Copilot, Codex), and steps to reproduce
- For inaccurate YAML generation, include the prompt used and the expected vs actual output

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes following the conventions below
4. Test your changes (see [Development](#development))
5. Commit with a clear message
6. Push to your fork and open a pull request

### Skill Conventions

- **SKILL.md** files must include frontmatter (`name`, `description`, `license`) and a phased workflow
- Keep SKILL.md under ~15KB — heavy reference material goes in `references/`
- Workflows are explicit step-by-step, not open-ended
- Reference docs are actionable checklists and lookup tables, not tutorials
- Edge cases section prevents false positives on common patterns
- Scripts use awk where possible and avoid dependencies beyond standard POSIX tools

### Reference Documentation

- Use checklist format (`- [ ]`) for best practices and audit items
- Include concrete examples and YAML snippets
- Cite specific API versions — don't leave them ambiguous
- When covering a CRD, verify field names against the actual schema

### Test Fixtures

- Place test fixtures under `tests/{skill-name}/`
- Each fixture should represent a distinct repo pattern or set of issues
- Use realistic but obviously fake data for any credentials or secrets

### Evals

- Each skill should have `evals/evals.json` with evaluation scenarios
- Each eval needs specific, mechanically verifiable expectations
- Test the evals by running them through the skill workflow

## Development

```shell
# Install prerequisites (macOS)
brew bundle

# Download Argo CRD schemas
make download-schemas

# Run discovery script on test fixtures
make test-discover

# Run validation script on test fixtures
make test-validate
```

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
