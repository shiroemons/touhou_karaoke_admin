DEVBOX_PC_PORT_NUM ?= 53178
DEVBOX_PC_URL := http://localhost:$(DEVBOX_PC_PORT_NUM)

.PHONY: all setup setup-git-hooks shell versions up tui logs down status ps restart fix-pg health doctor recover recover-force kill-orphan-ports \
	server jobs console console-sandbox bundle \
	dbinit dbconsole migrate migrate-redo rollback dbseed \
	update-originals-all seed-originals seed-original-songs seed-originals-all \
	minitest js-test minitest-assets rubocop rubocop-correct rubocop-correct-all \
	export-for-algolia check-algolia export-karaoke-songs import-karaoke-songs \
	export-display-artists import-display-artists \
	import-touhou-music import-touhou-music-slim \
	check-expired-joysound delete-expired-joysound \
	stats data-duplicate-report data-duplicate-impact-report db-dump db-restore \
	docker-init docker-up docker-down docker-server \
	docker-console docker-console-sandbox docker-bundle \
	docker-dbinit docker-dbconsole docker-migrate docker-migrate-redo docker-rollback docker-dbseed \
	docker-update-originals-all docker-seed-originals docker-seed-original-songs docker-seed-originals-all \
	docker-minitest docker-rubocop docker-rubocop-correct docker-rubocop-correct-all docker-bash \
	docker-export-for-algolia docker-check-algolia docker-export-karaoke-songs docker-import-karaoke-songs \
	docker-export-display-artists docker-import-display-artists \
	docker-import-touhou-music docker-import-touhou-music-slim \
	docker-check-expired-joysound docker-delete-expired-joysound \
	docker-stats docker-db-dump docker-db-restore \
	help

all: help

# ============================================================
# devbox環境コマンド (デフォルト)
# ============================================================

setup: ## Initialize devbox environment
	devbox run setup

setup-git-hooks: ## Configure repository Git hooks
	git config --local core.hooksPath .githooks

shell: ## Enter devbox shell
	devbox shell

versions: ## Show devbox environment tool versions
	@devbox run -- bash -c 'echo "Ruby: $$(ruby --version)"; echo "Rails: $$(bin/rails --version 2>/dev/null || echo N/A)"; echo "Node: $$(node --version)"; echo "Yarn: $$(yarn --version)"; echo "PostgreSQL: $$(psql --version)"; echo "Bundler: $$(bundler --version 2>/dev/null)"' 2>&1 | grep -v '東方カラオケ' | grep -v 'warning:' | grep -v '/nix/store' | grep -v '^Info:' | grep -v '^$$' | sed -e 's/ruby //' -e 's/Rails //' -e 's/psql (PostgreSQL) //' -e 's/Bundler version //' -e 's/ (.*//'

up: ## Start PostgreSQL and Rails server (background)
	@if curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1; then \
		echo "サービスは既に起動しています"; \
	else \
		PID_FILE=".devbox/virtenv/postgresql_18/data/postmaster.pid"; \
		if [ -f "$$PID_FILE" ]; then \
			PID=$$(head -1 "$$PID_FILE"); \
			if ! kill -0 "$$PID" 2>/dev/null; then \
				echo "古いpostmaster.pidを検出しました。削除します..."; \
				rm -f "$$PID_FILE"; \
			fi; \
		fi; \
		devbox services up --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) -b --pcport $(DEVBOX_PC_PORT_NUM); \
	fi
	@$(MAKE) --no-print-directory versions
	@$(MAKE) --no-print-directory status

tui: ## Start PostgreSQL and Rails server (TUI mode)
	devbox services up --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) --pcport $(DEVBOX_PC_PORT_NUM)

logs: ## Show Rails server logs
	tail -f log/development.log

down: ## Stop devbox services
	@if curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1 || devbox run -- pg_isready -h /tmp -p 5432 >/dev/null 2>&1; then \
		curl -fsS -X POST $(DEVBOX_PC_URL)/project/stop >/dev/null 2>&1 || devbox services stop --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) 2>/dev/null || true; \
		echo "サービス停止を要求しました"; \
	else \
		echo "サービスは起動していません"; \
	fi

status: ## Show devbox services status
	@if curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1; then \
		echo "Rails:      Ready (http://127.0.0.1:3000/up)"; \
	else \
		echo "Rails:      Not running"; \
	fi
	@if devbox run -- pg_isready -h /tmp -p 5432 >/dev/null 2>&1; then \
		echo "PostgreSQL: Ready (/tmp:5432)"; \
	else \
		echo "PostgreSQL: Not running"; \
	fi

ps: status ## Show devbox services status (alias)

restart: ## Restart devbox services
	@$(MAKE) --no-print-directory recover

fix-pg: ## Fix PostgreSQL by removing stale PID and restarting
	@echo "PostgreSQLを修復します..."
	@curl -fsS -X POST $(DEVBOX_PC_URL)/project/stop >/dev/null 2>&1 || devbox services stop --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) 2>/dev/null || true
	@rm -f .devbox/virtenv/postgresql_18/data/postmaster.pid
	@echo "postmaster.pidを削除しました。再起動します..."
	@devbox services up --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) -b --pcport $(DEVBOX_PC_PORT_NUM)
	@$(MAKE) --no-print-directory status

health: ## Check Rails and PostgreSQL status
	@echo "=== devbox services ==="
	@$(MAKE) --no-print-directory status
	@echo ""
	@echo "=== listening ports ==="
	@lsof -iTCP -sTCP:LISTEN -P 2>/dev/null | grep -E ':(3000|5432)' || true
	@if ! curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1; then \
		if (lsof -tiTCP:3000 -sTCP:LISTEN >/dev/null 2>&1 || lsof -tiTCP:5432 -sTCP:LISTEN >/dev/null 2>&1) && ! curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1; then \
			echo ""; \
			echo "WARNING: devbox管理外の孤児プロセスがポートを掴んでいる可能性があります。make recover-force で掃除できます。"; \
		fi; \
	fi
	@echo ""
	@echo "=== HTTP health ==="
	@curl -s -o /dev/null -w '  /up    status=%{http_code} time=%{time_total}s\n' http://127.0.0.1:3000/up || true
	@curl -s -o /dev/null -w '  /admin status=%{http_code} time=%{time_total}s\n' http://127.0.0.1:3000/admin || true

doctor: health ## Alias for health

recover: ## Stop devbox services and restart them in the background
	@echo "devboxサービスを停止します"
	@curl -fsS -X POST $(DEVBOX_PC_URL)/project/stop >/dev/null 2>&1 || devbox services stop --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) 2>/dev/null || true
	@if lsof -tiTCP:3000 -sTCP:LISTEN >/dev/null 2>&1 || lsof -tiTCP:5432 -sTCP:LISTEN >/dev/null 2>&1; then \
		echo "devbox停止後も 3000/5432 のいずれかが使用中です。"; \
		echo "孤児プロセスを停止するには make recover-force を実行してください。"; \
		$(MAKE) --no-print-directory health; \
		exit 1; \
	fi
	@echo "devboxサービスをバックグラウンドで起動します"
	@devbox services up --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) -b --pcport $(DEVBOX_PC_PORT_NUM)
	@echo "Railsの /up を待機します"
	@for i in $$(seq 1 30); do \
		if curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1; then \
			echo "Rails is ready"; \
			$(MAKE) --no-print-directory health; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Rails did not become ready within 30 seconds"; \
	$(MAKE) --no-print-directory health; \
	exit 1

recover-force: ## Stop orphan processes on 3000/5432 and restart devbox services
	@echo "devboxサービスを停止します"
	@curl -fsS -X POST $(DEVBOX_PC_URL)/project/stop >/dev/null 2>&1 || devbox services stop --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) 2>/dev/null || true
	@$(MAKE) --no-print-directory kill-orphan-ports
	@echo "devboxサービスをバックグラウンドで起動します"
	@devbox services up --env DEVBOX_PC_PORT_NUM=$(DEVBOX_PC_PORT_NUM) -b --pcport $(DEVBOX_PC_PORT_NUM)
	@echo "Railsの /up を待機します"
	@for i in $$(seq 1 30); do \
		if curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1; then \
			echo "Rails is ready"; \
			$(MAKE) --no-print-directory health; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Rails did not become ready within 30 seconds"; \
	$(MAKE) --no-print-directory health; \
	exit 1

kill-orphan-ports: ## Stop orphan processes listening on 3000/5432
	@pids="$$(lsof -tiTCP:3000 -sTCP:LISTEN 2>/dev/null; lsof -tiTCP:5432 -sTCP:LISTEN 2>/dev/null)"; \
	if [ -n "$$pids" ]; then \
		echo "孤児プロセスを停止します: $$pids"; \
		kill $$pids 2>/dev/null || true; \
		sleep 2; \
	fi; \
	pids="$$(lsof -tiTCP:3000 -sTCP:LISTEN 2>/dev/null; lsof -tiTCP:5432 -sTCP:LISTEN 2>/dev/null)"; \
	if [ -n "$$pids" ]; then \
		echo "通常終了しない孤児プロセスを強制停止します: $$pids"; \
		kill -9 $$pids 2>/dev/null || true; \
		sleep 1; \
	fi

server: ## Run Rails server
	devbox run server

jobs: ## Run Solid Queue worker
	devbox run jobs

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

js-test: ## Run JavaScript tests
	devbox run -- yarn test:js

minitest-assets: ## Run tests and rebuild JS/CSS assets
	$(MAKE) --no-print-directory minitest
	devbox run test:assets

rubocop: ## Run rubocop
	devbox run rubocop

rubocop-correct: ## Run rubocop (auto correct)
	devbox run rubocop:fix

rubocop-correct-all: ## Run rubocop (auto correct all)
	devbox run rubocop:fix:all

export-for-algolia: ## Export songs for Algolia
	devbox run export:algolia

check-algolia: ## Check Algolia changes and output only changed records
	devbox run check:algolia

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

data-duplicate-report: ## Report duplicate rows that block future unique indexes
	devbox run data:duplicates

data-duplicate-impact-report: ## Report duplicate row impact without changing data
	devbox run -- bin/rails data_integrity:duplicate_impact_report

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
	docker compose exec postgres-18 pg_dump -Fc --no-owner -v -d postgres://postgres:@localhost/touhou_karaoke_admin_development -f /tmp/data/dev.bak

docker-db-restore: ## [Docker] Database restore
	@if test -f ./tmp/dev.bak; then \
		docker compose exec postgres-18 pg_restore --no-privileges --no-owner --clean -v -d postgres://postgres:@localhost/touhou_karaoke_admin_development /tmp/data/dev.bak; \
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
