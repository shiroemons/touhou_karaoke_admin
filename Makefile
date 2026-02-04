all: help

# ============================================================
# devbox環境コマンド (デフォルト)
# ============================================================

setup: ## Initialize devbox environment
	devbox run setup

shell: ## Enter devbox shell
	devbox shell

up: ## Start PostgreSQL and Rails server (background)
	devbox services up -b

tui: ## Start PostgreSQL and Rails server (TUI mode)
	devbox services up

logs: ## Show Rails server logs
	tail -f log/development.log

down: ## Stop devbox services
	devbox services stop || true

status: ## Show devbox services status
	devbox services status

server: ## Run Rails server
	devbox run server

console: ## Run Rails console
	devbox run console

console-sandbox: ## Run Rails console (sandbox)
	devbox run console:sandbox

bundle: ## Run bundle install
	devbox run bundle

dbinit: ## Initialize database (drop and setup)
	devbox run db:init

dbconsole: ## Run database console
	devbox run db:console

migrate: ## Run db:migrate
	devbox run db:migrate

migrate-redo: ## Run db:migrate:redo
	devbox run db:migrate:redo

rollback: ## Run db:rollback
	devbox run db:rollback

dbseed: ## Run db:seed
	devbox run db:seed

update-originals-all: ## Update both originals and original songs data (upsert)
	devbox run update:originals

seed-originals: ## Import originals data only (truncate and reimport)
	devbox run seed:originals

seed-original-songs: ## Import original songs data only (truncate and reimport)
	devbox run seed:original_songs

seed-originals-all: ## Import both originals and original songs data (truncate and reimport)
	devbox run seed:originals:all

minitest: ## Run tests
	devbox run test

rubocop: ## Run rubocop
	devbox run rubocop

rubocop-correct: ## Run rubocop (auto correct)
	devbox run rubocop:fix

rubocop-correct-all: ## Run rubocop (auto correct all)
	devbox run rubocop:fix:all

export-for-algolia: ## Export songs for Algolia
	devbox run export:algolia

export-karaoke-songs: ## Export karaoke songs
	devbox run export:karaoke

import-karaoke-songs: ## Import karaoke songs
	devbox run import:karaoke

export-display-artists: ## Export display artists with circles
	devbox run export:artists

import-display-artists: ## Import display artists with circles
	devbox run import:artists

import-touhou-music: ## Import touhou music data
	devbox run import:touhou

import-touhou-music-slim: ## Import touhou music slim data
	devbox run import:touhou:slim

check-expired-joysound: ## Check expired JOYSOUND(うたスキ) records in Algolia
	devbox run check:joysound

delete-expired-joysound: ## Delete expired JOYSOUND(うたスキ) records from Algolia
	devbox run delete:joysound

stats: ## Generate statistics
	devbox run stats

db-dump: ## Database backup
	devbox run db:backup

db-restore: ## Database restore
	devbox run db:restore

# ============================================================
# Docker環境コマンド (docker-プレフィックス)
# ============================================================

docker-init: ## [Docker] Initialize environment
	docker compose build
	docker compose run --rm web bin/setup

docker-up: ## [Docker] Do docker compose up -d
	docker compose up -d

docker-down: ## [Docker] Do docker compose down
	docker compose down

docker-server: ## [Docker] Run server
	docker compose run --rm --service-ports web

docker-console: ## [Docker] Run console
	docker compose run --rm web bin/rails console

docker-console-sandbox: ## [Docker] Run console(sandbox)
	docker compose run --rm web bin/rails console --sandbox

docker-bundle: ## [Docker] Run bundle install
	docker compose run --rm web bundle config set clean true
	docker compose run --rm web bundle install --jobs=4

docker-dbinit: ## [Docker] Initialize database
	docker compose run --rm web bin/rails db:drop db:setup

docker-dbconsole: ## [Docker] Run dbconsole
	docker compose run --rm web bin/rails dbconsole

docker-migrate: ## [Docker] Run db:migrate
	docker compose run --rm web bin/rails db:migrate

docker-migrate-redo: ## [Docker] Run db:migrate:redo
	docker compose run --rm web bin/rails db:migrate:redo

docker-rollback: ## [Docker] Run db:rollback
	docker compose run --rm web bin/rails db:rollback

docker-dbseed: ## [Docker] Run db:seed
	docker compose run --rm web bin/rails db:seed

docker-update-originals-all: ## [Docker] Update both originals and original songs data (upsert)
	docker compose run --rm web bin/rails db:seed:update_originals

docker-seed-originals: ## [Docker] Import originals data only (truncate and reimport)
	docker compose run --rm web bin/rails db:seed:originals

docker-seed-original-songs: ## [Docker] Import original songs data only (truncate and reimport)
	docker compose run --rm web bin/rails db:seed:original_songs

docker-seed-originals-all: ## [Docker] Import both originals and original songs data (truncate and reimport)
	docker compose run --rm web bin/rails db:seed:originals_all

docker-minitest: ## [Docker] Run test
	docker compose run --rm -e RAILS_ENV=test web bin/rails db:test:prepare
	docker compose run --rm -e RAILS_ENV=test web bin/rails test

docker-rubocop: ## [Docker] Run rubocop
	docker compose run --rm web bundle exec rubocop --parallel

docker-rubocop-correct: ## [Docker] Run rubocop (auto correct)
	docker compose run --rm web bundle exec rubocop --autocorrect

docker-rubocop-correct-all: ## [Docker] Run rubocop (auto correct all)
	docker compose run --rm web bundle exec rubocop --autocorrect-all

docker-bash: ## [Docker] Run bash in web container
	docker compose run --rm web bash

docker-export-for-algolia: ## [Docker] Export songs for Algolia
	docker compose run --rm web bin/rails r lib/export_songs.rb

docker-export-karaoke-songs: ## [Docker] Export karaoke songs
	docker compose run --rm web bin/rails r lib/export_karaoke_songs.rb

docker-import-karaoke-songs: ## [Docker] Import karaoke songs
	docker compose run --rm web bin/rails r lib/import_karaoke_songs.rb

docker-export-display-artists: ## [Docker] Export display artists with circles
	docker compose run --rm web bin/rails r lib/export_display_artists_with_circles.rb

docker-import-display-artists: ## [Docker] Import display artists with circles
	docker compose run --rm web bin/rails r lib/import_display_artists_with_circles.rb

docker-import-touhou-music: ## [Docker] Import touhou music data
	docker compose run --rm web bin/rails r lib/import_touhou_music.rb

docker-import-touhou-music-slim: ## [Docker] Import touhou music slim data
	docker compose run --rm web bin/rails runner lib/import_touhou_music_slim.rb

docker-check-expired-joysound: ## [Docker] Check expired JOYSOUND(うたスキ) records in Algolia
	docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --verbose

docker-delete-expired-joysound: ## [Docker] Delete expired JOYSOUND(うたスキ) records from Algolia
	docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --delete --verbose

docker-stats: ## [Docker] Generate statistics
	docker compose run --rm web bin/rails r lib/stats.rb

docker-db-dump: ## [Docker] Database backup
	mkdir -p tmp/data
	docker compose exec postgres-16 pg_dump -Fc --no-owner -v -d postgres://postgres:@localhost/touhou_karaoke_admin_development -f /tmp/data/dev.bak

docker-db-restore: ## [Docker] Database restore
	@if test -f ./tmp/dev.bak; then \
		docker compose exec postgres-16 pg_restore --no-privileges --no-owner --clean -v -d postgres://postgres:@localhost/touhou_karaoke_admin_development /tmp/data/dev.bak; \
	else \
		echo "Error: ./tmp/dev.bak does not exist."; \
		exit 1; \
	fi

help:
	@echo "=== devbox環境コマンド ==="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -v 'Docker' | sort | awk -F':.*?## ' '{printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "=== Docker環境コマンド ==="
	@grep -E '^[a-zA-Z_-]+:.*?## \[Docker\].*$$' $(MAKEFILE_LIST) | sort | awk -F':.*?## ' '{printf "\033[33m%-25s\033[0m %s\n", $$1, $$2}'
