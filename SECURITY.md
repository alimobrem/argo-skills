# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it
responsibly by emailing the maintainers directly rather than opening a public issue.

**Do not open a public GitHub issue for security vulnerabilities.**

When reporting, please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will acknowledge receipt within 48 hours and aim to provide a fix or
mitigation within 7 days for critical issues.

## Scope

This project contains AI agent skill definitions, reference documentation,
and shell scripts. The test fixtures intentionally contain fake credentials
(e.g., `supersecretpassword123`, dummy bearer tokens) as audit targets —
these are not real secrets.

Security concerns most relevant to this project:

- Shell scripts in `skills/*/scripts/` that run on user machines
- Skill instructions that could cause agents to take unintended actions
- Reference documentation that recommends insecure configurations
