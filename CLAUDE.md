# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview
東方カラオケ検索管理サイト (Touhou Karaoke Search Admin Site) - A Rails application for managing and searching Touhou music available in Japanese karaoke systems (DAM and JOYSOUND).

## Development Commands

### Environment Setup
```bash
# Initial setup (builds Docker image and runs bin/setup)
make init

# Start Docker containers
make start

# Run development server (accessible at http://localhost:3000)
make server
```

### Database Operations
```bash
# Initialize database (drop and setup)
make dbinit

# Run migrations
make migrate

# Rollback migrations
make rollback

# Seed database
make dbseed

# Database console
make dbconsole
```

### Development Tools
```bash
# Rails console
make console

# Rails console in sandbox mode
make console-sandbox

# Run tests
make minitest

# Run Rubocop linter
make rubocop

# Auto-correct Rubocop issues
make rubocop-correct
make rubocop-correct-all

# Bundle install
make bundle
```

### Data Import/Export
```bash
# Export songs for Algolia search
make export-for-algolia

# Export karaoke songs
make export-karaoke-songs

# Import karaoke songs
make import-karaoke-songs

# Update originals data
make update-originals
make update-original-songs
make update-originals-all
```

## Architecture

### Technology Stack
- Ruby 3.3.6
- Rails 7.1.0
- PostgreSQL
- Docker for containerization
- Avo for admin interface
- AlgoliaSearch for search functionality
- Ferrum for web scraping

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
- **Branch naming**: Use descriptive English branch names (e.g., `add-feature-name`, `fix-bug-description`)

Example commit message format:
```
機能: ユーザー認証システムを追加

- JWTトークンによる認証を実装
- ログイン/ログアウトAPIを追加
- セッション管理機能を追加
```