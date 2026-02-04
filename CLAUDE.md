# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview
東方カラオケ検索管理サイト (Touhou Karaoke Search Admin Site) - A Rails application for managing and searching Touhou music available in Japanese karaoke systems (DAM and JOYSOUND).

## Development Environment

This project uses **devbox** (recommended) for local development. Docker is available as an alternative.

### devbox (Recommended)

devbox provides a reproducible development environment using Nix packages. It does NOT use Homebrew.

```bash
# Enter devbox shell
devbox shell

# Start PostgreSQL service
make up

# Initial setup (bundle install, yarn install, db:prepare)
make setup

# Run development server (http://localhost:3000)
make server

# Stop PostgreSQL service
make down
```

### Docker (Alternative)

Docker commands use `docker-` prefix:

```bash
make docker-up        # Start containers
make docker-server    # Run server
make docker-down      # Stop containers
```

## Development Commands

All commands below work in devbox environment. For Docker, add `docker-` prefix.

### Database Operations
```bash
make dbinit       # Initialize database (drop and setup)
make migrate      # Run migrations
make migrate-redo # Redo last migration
make rollback     # Rollback migrations
make dbseed       # Seed database
make dbconsole    # Database console
make db-dump      # Backup to tmp/data/dev.bak
make db-restore   # Restore from backup
```

### Development Tools
```bash
make console          # Rails console
make console-sandbox  # Rails console (sandbox mode)
make minitest         # Run tests
make rubocop          # Run Rubocop linter
make rubocop-correct  # Auto-correct Rubocop issues
make bundle           # Bundle install
```

### Data Import/Export
```bash
make export-for-algolia     # Export songs for Algolia
make export-karaoke-songs   # Export karaoke songs
make import-karaoke-songs   # Import karaoke songs
make export-display-artists # Export display artists
make import-display-artists # Import display artists
make import-touhou-music    # Import Touhou music data
make stats                  # Generate statistics
```

## Architecture

### Technology Stack
- Ruby 3.4.4
- Rails 8.0.2
- PostgreSQL 16
- devbox (Nix-based development environment)
- Docker (alternative containerization)
- Avo for admin interface
- AlgoliaSearch for search functionality
- Ferrum for web scraping (requires Chromium)

### Key Models
- **Song**: Central model representing karaoke songs
  - Supports multiple karaoke types: DAM, JOYSOUND, JOYSOUND(うたスキ)
  - Linked to original Touhou songs via `original_songs`
  - Tracks availability across different karaoke delivery models
  
- **DisplayArtist**: Artists as displayed in karaoke systems
  - Can be linked to multiple circles (Touhou music groups)
  
- **Original**: Original Touhou works (games, albums, etc.)
  
- **OriginalSong**: Individual songs from original Touhou works
  
- **KaraokeDeliveryModel**: Different karaoke machine models (e.g., "LIVE DAM", "JOYSOUND MAX GO")

### Data Collection
The application fetches karaoke data from:
- **DAM**: Via `DamArtistUrl` and `DamSong` models
- **JOYSOUND**: Via `JoysoundSong` and `JoysoundMusicPost` models

Data fetching is handled through Avo actions in `app/avo/actions/`.

### Admin Interface
The admin interface is built with Avo and mounted at the root path (`/`). Resources are defined in `app/avo/resources/` with corresponding controllers in `app/controllers/avo/`.

## Testing
- Test files are located in the `test/` directory
- Run tests with `make minitest`
- Ensure database is prepared for testing before running tests

## Linting
- Uses Rubocop for Ruby code style
- Configuration follows standard Rails conventions
- Run `make rubocop` to check for issues
- Use `make rubocop-correct` for auto-corrections

## Development Workflow
When making code modifications:
1. Create a new branch before making changes (if on master branch)
2. Make your modifications
3. Commit your changes with a descriptive message in Japanese
4. Push to remote repository
5. Create a Pull Request for review in Japanese

This workflow ensures code changes are properly reviewed and tracked through version control.

### Git Commit and Pull Request Guidelines
- **Commit messages**: Must be written in Japanese
- **Pull Request titles and descriptions**: Must be written in Japanese
- **Branch naming**: Use descriptive English branch names (e.g., `feature/add-feature-name`, `feature/fix-bug-description`)
- **Do NOT include**: `🤖 Generated with [Claude Code]` or `Co-Authored-By: Claude` in commit messages

Example commit message format:
```
ユーザー認証システムを追加

- JWTトークンによる認証を実装
- ログイン/ログアウトAPIを追加
- セッション管理機能を追加
```