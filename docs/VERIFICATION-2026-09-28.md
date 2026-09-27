# Verification Record - 2026-09-28

## Scope

This record covers the codex/security-and-portfolio-hardening branch on a Windows workstation. It verifies dependency reproducibility, static checks, production compilation, bounded authentication, a disposable local libSQL database, synthetic portfolio data and browser screenshots. It does not connect to a real Turso database, SSH target, Git provider or production server.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Credential removal from current tree | Pass | Tracked .env removed; .env and .env.* ignored except .env.example |
| Dependency install | Pass | npm install completed from the regenerated package-lock.json |
| Dependency audit | Pass | npm audit reported 0 vulnerabilities |
| Lint | Pass | npm run lint completed with 0 errors and 0 warnings |
| Production build | Pass with documented warning | Next.js 15.5.26 generated 25 static/dynamic routes |
| Wrong login | Pass | POST /api/login returned 401 |
| Correct configured login | Pass | POST /api/login returned 200 and the configured API token |
| Protected API inventory | Pass | Every callable route handler except `/api/login` performs token validation; explicit method-not-allowed stubs only return 405 |
| Missing Bearer token | Pass | 20 representative protected method/path pairs returned 401 before database, SSH, process or deployment work |
| Arbitrary Bearer token | Pass | The same 20 protected method/path pairs returned 401 |
| Local database schema | Pass | Drizzle pushed the current schema into a new `file:` libSQL database in the Windows temporary directory |
| Synthetic portfolio seed | Pass | POST /api/seed created 2 systems, 2 projects, 5 credential-free targets, 4 users and 2 deployment records |
| Seed idempotence | Pass | A second seed call preserved the same record counts across all five data groups |
| Valid Bearer boundary | Pass | Valid credentials reached the local database and returned systems, projects, targets, users and deployment history |
| Browser dashboard | Pass | The dashboard rendered database-backed counts and recent deployments at 1440 x 900 |
| Browser deployment history | Pass | The corrected history client rendered named systems, projects, packages and targets from `/api/deployments/history` |
| Screenshot reproducibility | Pass | The environment-only CDP script generated both PNG files without storing login credentials |
| Current-tree secret scan | Pass with reviewed placeholder | No AWS, GitHub, JWT-shaped or non-placeholder libSQL credential was found; the private-key match is a UI input placeholder only |

## Build warning

Webpack reported that the optional ssh2 native crypto binding was unavailable. The package retains its JavaScript fallback and the production build completed. Real SSH acceptance must still test password and key authentication, host-key policy, SFTP transfer, command restrictions, timeout and cleanup against disposable targets.

## Security boundary

The current environment-variable token gate is materially safer than the historical fixed password and accept-any-Bearer behavior, but it is not a complete production identity system. Production use still requires identity/session design, RBAC enforcement, command and path allowlists, CSRF and rate limits, trusted-proxy configuration, audit-integrity checks and isolated end-to-end tests.

The bounded API test submitted a valid token only to the disposable local seed and read-only data endpoints. Process-control, SSH, deployment and rollback paths were tested only for rejection of missing and arbitrary credentials, so verification could not alter the workstation or a remote target.

The historical Turso token remains exposed in Git history until it is revoked by the account owner. Provider-side revocation is mandatory. History rewriting alone is not credential revocation.

## Not verified

- Provider-side revocation of the historical Turso token.
- Connection to a real database using newly issued credentials.
- SSH, SFTP, deployment, rollback or process-control execution.
- Docker image and systemd/nginx deployment.
- Production security, capacity, availability or customer acceptance.
