# Repository Guidelines

## Project Structure & Module Organization

This is a Ruby on Rails admin application for managing Touhou karaoke data. Core code lives in `app/`: models, controllers, admin policies, background jobs, helpers, views, and services. Admin UI templates are under `app/views/admin`, JavaScript in `app/javascript`, and Tailwind/CSS assets in `app/assets`.

Database migrations, schema, seeds, and TSV fixtures live in `db/`. Import/export and maintenance scripts are in `lib/`. Tests mirror Rails structure under `test/`.

## Build, Test, and Development Commands

Use `devbox` as the default local environment.

- `make setup`: install dependencies and prepare the database.
- `make up`: start PostgreSQL, Rails, Solid Queue, and asset watchers.
- `make server`: run only the Rails server at `http://localhost:3000`.
- `make jobs`: run the Solid Queue worker for async admin operations.
- `make migrate`: apply database migrations.
- `make minitest`: run the full Minitest suite.
- `make rubocop`: run Ruby lint checks.
- `yarn build` and `yarn build:css`: build JavaScript and Tailwind assets.

Docker alternatives exist with the `docker-` prefix, such as `make docker-minitest`.

## Coding Style & Naming Conventions

Target Ruby `4.0.3`, Node `>=24 <25`, and Yarn `1.22.22`. Follow Rails conventions: `snake_case` files and methods, `CamelCase` classes/modules, and REST-style controller actions. Keep admin behavior inside existing resource, policy, helper, and service boundaries.

RuboCop, `rubocop-rails`, and `rubocop-performance` define Ruby style. Run `make rubocop` before committing, or `make rubocop-correct` for safe automatic fixes.

## Testing Guidelines

Tests use Minitest with Rails fixtures. Add or update tests for behavior changes, especially admin workflows, authorization policies, imports/exports, database queries, and external scraping failures. Name test files after the class or feature, for example `test/services/delivery_model_manager_test.rb`.

Run `make minitest` locally. For query-sensitive admin pages, include regression coverage that detects repeated SQL patterns or N+1 behavior when practical.

## Commit & Pull Request Guidelines

Use Conventional Commits with Japanese descriptions: `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`, `refactor: ...`. Keep commits focused and describe the user-visible or operational impact in Japanese.

Before opening a PR, run `make minitest` and `make rubocop`. Write PR titles and descriptions in Japanese. Include a concise summary, relevant issue links, migration notes, and screenshots for visible admin UI changes. Mention any required data backfill, environment variable, or deployment step.

## Security & Configuration Tips

Do not commit secrets. Use Rails credentials or environment variables for API keys such as Algolia. Validate imported TSV data, scraped responses, and other external input. Treat network calls as fallible and keep timeout, retry, and error reporting behavior explicit.
