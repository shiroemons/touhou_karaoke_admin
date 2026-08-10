# Backward-compatible entry point.
#
# Taskfile.yml is the source of truth for non-Docker project commands. Keep this file so
# existing scripts and developer habits using `make <task>` continue to work.

.DEFAULT_GOAL := all

TASK_RUNNER ?= mise exec -- task
DEVBOX_RAILS_PORT ?=
DEVBOX_PC_PORT_NUM ?= 53178
export DEVBOX_RAILS_PORT
export DEVBOX_PC_PORT_NUM

TASKS := \
	all setup setup-git-hooks shell versions up tui logs down status ps restart fix-pg health doctor recover recover-force kill-orphan-ports \
	server jobs console console-sandbox bundle \
	dbinit dbconsole migrate migrate-redo rollback dbseed db-dump db-restore \
	update-originals-all seed-originals seed-original-songs seed-originals-all \
	minitest js-test minitest-assets rubocop rubocop-correct rubocop-correct-all \
	build build-css playwright-cli \
	export-for-algolia check-algolia export-karaoke-songs import-karaoke-songs \
	export-display-artists import-display-artists \
	import-touhou-music import-touhou-music-slim \
	check-expired-joysound delete-expired-joysound \
	stats data-duplicate-report data-duplicate-impact-report

DOCKER_TASKS := \
	docker-init docker-up docker-down docker-server \
	docker-console docker-console-sandbox docker-bundle \
	docker-dbinit docker-dbconsole docker-migrate docker-migrate-redo docker-rollback docker-dbseed \
	docker-update-originals-all docker-seed-originals docker-seed-original-songs docker-seed-originals-all \
	docker-minitest docker-rubocop docker-rubocop-correct docker-rubocop-correct-all docker-bash \
	docker-export-for-algolia docker-check-algolia docker-export-karaoke-songs docker-import-karaoke-songs \
	docker-export-display-artists docker-import-display-artists \
	docker-import-touhou-music docker-import-touhou-music-slim \
	docker-check-expired-joysound docker-delete-expired-joysound \
	docker-stats docker-db-dump docker-db-restore

.PHONY: $(TASKS) $(DOCKER_TASKS) help
.SILENT: $(TASKS) $(DOCKER_TASKS) help

$(TASKS):
	@$(TASK_RUNNER) $@

# Docker commands intentionally remain Makefile-only compatibility targets.

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

docker-check-algolia: ## [Docker] Check Algolia changes and output only changed records
	docker compose run --rm web bin/rails runner lib/check_algolia_upload.rb --verbose --output-changes tmp/karaoke_songs.json

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
	docker compose exec -T postgres-18 pg_dump -Fc --no-owner -v -h localhost -U postgres -d touhou_karaoke_admin_development > tmp/data/development-primary.bak.tmp
	docker compose exec -T postgres-18 pg_dump -Fc --no-owner -v -h localhost -U postgres -d touhou_karaoke_admin_development_queue > tmp/data/development-queue.bak.tmp
	docker compose exec -T postgres-18 pg_dumpall --globals-only --no-role-passwords -h localhost -U postgres > tmp/data/globals.sql.tmp
	docker compose exec -T postgres-18 pg_restore --list < tmp/data/development-primary.bak.tmp >/dev/null
	docker compose exec -T postgres-18 pg_restore --list < tmp/data/development-queue.bak.tmp >/dev/null
	test -s tmp/data/globals.sql.tmp
	mv tmp/data/development-primary.bak.tmp tmp/data/development-primary.bak
	mv tmp/data/development-queue.bak.tmp tmp/data/development-queue.bak
	mv tmp/data/globals.sql.tmp tmp/data/globals.sql

docker-db-restore: ## [Docker] Database restore
	@if test -f ./tmp/data/development-primary.bak && test -f ./tmp/data/development-queue.bak; then \
		set -e; \
		docker compose exec -T postgres-18 pg_restore --list < ./tmp/data/development-primary.bak >/dev/null; \
		docker compose exec -T postgres-18 pg_restore --list < ./tmp/data/development-queue.bak >/dev/null; \
		docker compose exec postgres-18 dropdb --if-exists --force -h localhost -U postgres touhou_karaoke_admin_development; \
		docker compose exec postgres-18 dropdb --if-exists --force -h localhost -U postgres touhou_karaoke_admin_development_queue; \
		docker compose exec postgres-18 createdb -h localhost -U postgres touhou_karaoke_admin_development; \
		docker compose exec postgres-18 createdb -h localhost -U postgres touhou_karaoke_admin_development_queue; \
		docker compose exec -T postgres-18 pg_restore --no-privileges --no-owner --exit-on-error --single-transaction -v -h localhost -U postgres -d touhou_karaoke_admin_development < ./tmp/data/development-primary.bak; \
		docker compose exec -T postgres-18 pg_restore --no-privileges --no-owner --exit-on-error --single-transaction -v -h localhost -U postgres -d touhou_karaoke_admin_development_queue < ./tmp/data/development-queue.bak; \
	else \
		echo "Error: primary and queue backups do not exist in ./tmp/data/."; \
		exit 1; \
	fi

help:
	@$(TASK_RUNNER) help
	@echo ""
	@echo "=== Docker環境コマンド ==="
	@grep -E '^[a-zA-Z_-]+:.*?## \[Docker\].*$$' $(MAKEFILE_LIST) | sort | awk -F':.*?## ' '{printf "\033[33m%-25s\033[0m %s\n", $$1, $$2}'
