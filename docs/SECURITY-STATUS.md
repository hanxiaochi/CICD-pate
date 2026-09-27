# Security Status and Credential Recovery

## Immediate credential action

A historical public commit added a non-placeholder Turso database URL and authentication token to `.env`. Removing the file from the current tree does not invalidate that token and does not remove it from Git history.

Before using this repository with any database:

1. Revoke the historical Turso token in the provider console.
2. Create a new development database or confirm the old database contains no sensitive data.
3. Generate a new least-privilege development token.
4. Store the new values only in a local ignored `.env` file or an approved secret manager.
5. Review access logs and the database contents for unexpected access.

The repository must not be described as remediated until provider-side revocation is confirmed. Rewriting Git history is optional cleanup after revocation; it is not a substitute for revocation.

## Current public-use boundary

This codebase is a portfolio prototype and is not approved for internet-facing production use. Before production deployment it still requires, at minimum:

- replacement of demo login behavior with a real identity and session system;
- consistent authorization checks based on verified identities and roles;
- strict allowlists for every remote command, path, repository and target;
- CSRF, rate-limit, audit-integrity and secret-lifecycle review;
- isolated integration tests against disposable SSH targets;
- dependency, container and deployment hardening;
- an independent security review for any environment containing production credentials.

## Local setup

Copy `.env.example` to `.env`, replace every placeholder, and keep the resulting file outside Git. Use separate credentials for development, test and production. Never use a public repository secret as a production credential.
