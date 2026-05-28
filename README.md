# Keens

Operating system for songwriting camps. Run the camp, capture the songs,
lock the splits before everyone leaves the room.

## Stack

- Rails 8 (Hotwire/Turbo, Propshaft, Tailwind, Solid Queue/Cache/Cable)
- Postgres
- Hosted on Render (auto-deploy from `main`)

Architecture decision lives on issue KEE-2.

## Local dev

```bash
brew install ruby@3.3 postgresql@16
bin/setup
bin/dev
```

Open <http://localhost:3000>.

## CI

GitHub Actions runs on every push and PR:

- `rubocop` lint
- `brakeman` + `bundler-audit` security scans
- `importmap audit` JS dependency scan
- Postgres-backed test suite (`bin/rails test`)
- System tests (`bin/rails test:system`)

Green required to merge to `main`.

## Deploy

Push to `main` &rarr; Render auto-deploys via `render.yaml`.

A static landing page also ships to GitHub Pages on every push to `main`
(see `.github/workflows/pages.yml`) as the public hello-world URL.
