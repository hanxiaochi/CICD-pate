# Rails API Skeleton for CI/CD Lite

This is a minimal Rails 7 API-only skeleton placed under backend/rails/ to serve the Next.js frontend.

It exposes placeholder endpoints compatible with the current UI contracts so you can boot quickly and iterate.

## Quick start

1) Install Ruby 3.3 and Bundler
2) cd backend/rails
3) bundle install
4) bundle exec puma -C config/puma.rb

Server runs at http://localhost:4000

## API endpoints (placeholders)
- POST /api/login => { token }
- GET /api/systems
- GET /api/projects
- GET /api/projects/:id/packages
- GET /api/targets?page=&pageSize=&q=
- POST /api/targets
- PUT /api/targets/:id
- DELETE /api/targets/:id
- POST /api/targets/test-ssh
- POST /api/targets/test-connection
- GET /api/targets/:id/fs?path=
- GET /api/targets/:id/processes
- POST /api/deployments
- GET /api/deployments/history
- POST /api/deployments/:id/rollback

All endpoints return demo data. Replace stubs with real implementations (models, migrations, services) as needed.

## Notes
- api_only = true
- SQLite config included; migrations are not required for stub responses.
- Add Net::SSH/Net::SCP and job queue when moving beyond placeholders.