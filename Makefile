all: help

init: ## Initialize environment
	docker compose build
	docker compose run --rm web bin/setup

up: ## Do docker compose up -d
	docker compose up -d

down: ## Do docker compose down
	docker compose down

server: ## Run server
	docker compose run --rm --service-ports web

console: ## Run console
	docker compose run --rm web bin/rails console

console-sandbox: ## Run console(sandbox)
	docker compose run --rm web bin/rails console --sandbox

bundle: ## Run bundle install
	docker compose run --rm web bundle config set clean true
	docker compose run --rm web bundle install --jobs=4

dbinit: ## Initialize database
	docker compose run --rm web bin/rails db:drop db:setup

dbconsole: ## Run dbconsole
	docker compose run --rm web bin/rails dbconsole

migrate: ## Run db:migrate
	docker compose run --rm web bin/rails db:migrate

migrate-redo: ## Run db:migrate:redo
	docker compose run --rm web bin/rails db:migrate:redo

rollback: ## Run db:rollback
	docker compose run --rm web bin/rails db:rollback

dbseed: ## Run db:seed
	docker compose run --rm web bin/rails db:seed

update-originals-all: ## Update both originals and original songs data (upsert)
	docker compose run --rm web bin/rails db:seed:update_originals

seed-originals: ## Import originals data only (truncate and reimport)
	docker compose run --rm web bin/rails db:seed:originals

seed-original-songs: ## Import original songs data only (truncate and reimport)
	docker compose run --rm web bin/rails db:seed:original_songs

seed-originals-all: ## Import both originals and original songs data (truncate and reimport)
	docker compose run --rm web bin/rails db:seed:originals_all

minitest: ## Run test
	docker compose run --rm -e RAILS_ENV=test web bin/rails db:test:prepare
	docker compose run --rm -e RAILS_ENV=test web bin/rails test

rubocop: ## Run rubocop
	docker compose run --rm web bundle exec rubocop --parallel

rubocop-correct: ## Run rubocop (auto correct)
	docker compose run --rm web bundle exec rubocop --autocorrect

rubocop-correct-all: ## Run rubocop (auto correct all)
	docker compose run --rm web bundle exec rubocop --autocorrect-all

bash: ## Run bash in web container
	docker compose run --rm web bash

export-for-algolia:
	docker compose run --rm web bin/rails r lib/export_songs.rb

export-karaoke-songs:
	docker compose run --rm web bin/rails r lib/export_karaoke_songs.rb

import-karaoke-songs:
	docker compose run --rm web bin/rails r lib/import_karaoke_songs.rb

export-display-artists:
	docker compose run --rm web bin/rails r lib/export_display_artists_with_circles.rb

import-display-artists:
	docker compose run --rm web bin/rails r lib/import_display_artists_with_circles.rb

import-touhou-music:
	docker compose run --rm web bin/rails r lib/import_touhou_music.rb

import-touhou-music-slim: ## Import touhou music slim data
	docker compose run --rm web bin/rails runner lib/import_touhou_music_slim.rb

check-expired-joysound: ## Check expired JOYSOUND(うたスキ) records in Algolia
	docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --verbose

delete-expired-joysound: ## Delete expired JOYSOUND(うたスキ) records from Algolia
	docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --delete --verbose

stats:
	docker compose run --rm web bin/rails r lib/stats.rb

db-dump: ## db dump
	mkdir -p tmp/data
	docker compose exec postgres-16 pg_dump -Fc --no-owner -v -d postgres://postgres:@localhost/touhou_karaoke_admin_development -f /tmp/data/dev.bak

db-restore: ## db restore
	@if test -f ./tmp/dev.bak; then \
		docker compose exec postgres-16 pg_restore --no-privileges --no-owner --clean -v -d postgres://postgres:@localhost/touhou_karaoke_admin_development /tmp/data/dev.bak; \
	else \
		echo "Error: ./tmp/dev.bak does not exist."; \
		exit 1; \
	fi

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk -F':.*?## ' '{printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'
