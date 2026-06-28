# 東方カラオケ検索管理サイト

東方Project関連のカラオケ配信データを管理する Rails 管理アプリケーションです。DAM、JOYSOUND、JOYSOUND ミュージックポストの取得データをもとに、楽曲、原曲、アーティスト、サークル、配信機種、外部配信 URL を整理します。

## 主な機能

### カラオケ楽曲管理

- **DAM / JOYSOUND / JOYSOUND ミュージックポスト対応**: 各サービスの取得データとカラオケ楽曲マスタを一元管理
- **楽曲情報の取得・更新**: DAM / JOYSOUND の検索結果、楽曲詳細、アーティスト情報、ミュージックポスト情報を取得
- **原曲との紐付け**: 東方原作・原曲データとカラオケ楽曲の関連を管理
- **配信機種管理**: DAM / JOYSOUND の機種別配信状況と表示順を管理
- **配信期限管理**: JOYSOUND ミュージックポストの配信期限を確認・更新

### 管理画面

- **Rails 管理 UI**: Controller / View / Policy / ResourceRegistry ベースの管理画面
- **ダッシュボード**: 楽曲数、原曲紐付け状況、配信種別、外部配信 URL などの状態を表示
- **検索・絞り込み・ソート**: Ransack と管理画面用フィルタによる一覧操作
- **非同期操作**: Solid Queue を使った取得・更新・検証処理と進捗表示
- **運用ワークフロー**: JOYSOUND ミュージックポスト、JOYSOUND、DAM、共通作業を手順化して実行
- **部分更新 UI**: 一覧の検索、フィルタ、ページング、進捗確認などを JavaScript で軽量更新

### データ入出力

- **TSV インポート / エクスポート**: 楽曲、原曲紐付け、アーティスト、初期 fixtures を管理
- **Algolia 連携**: 検索用 JSON の出力とアップロード差分確認
- **統計出力**: 楽曲・原曲・配信状況の集計
- **保守スクリプト**: 重複確認、配信機種名正規化、期限切れチェックなど

## 技術スタック

- Ruby 4.0.5
- Rails 8.1.x
- PostgreSQL 18
- Solid Queue
- Pundit
- Ransack
- Algolia Search
- Tailwind CSS 4 / daisyUI 5
- esbuild
- Node.js 24 / Yarn 1.22.22
- Minitest
- RuboCop / rubocop-rails / rubocop-performance

## 開発環境

このプロジェクトは **devbox** を標準の開発環境として使います。Docker 環境も代替手段として残していますが、通常の開発・テスト・Lint・DB 操作は `make` ターゲット経由で実行してください。

### devbox のインストール

```shell
curl -fsSL https://get.jetify.com/devbox | bash
```

### 初回セットアップ

1. 環境変数ファイルを作成します。

```shell
cp .env.devbox.template .env
```

Algolia を使う処理を実行する場合は、`.env` の `ALGOLIA_APPLICATION_ID`、`ALGOLIA_API_KEY`、`ALGOLIA_INDEX_NAME` を実値に変更してください。

管理画面に Basic 認証を付けたい場合は、`.env` に `TOUHOU_KARAOKE_ADMIN_BASIC_AUTH_USERNAME` と `TOUHOU_KARAOKE_ADMIN_BASIC_AUTH_PASSWORD` を両方設定してください。未設定の場合は認証なしで従来通り動作します。

2. devbox シェルに入ります。

```shell
devbox shell
```

3. PostgreSQL と開発用プロセスを起動します。

```shell
make up
```

4. 依存関係と DB を準備します。

```shell
make setup
```

初回は依存関係のインストール前に Rails / JS / CSS プロセスが一時的に失敗することがあります。その場合は `make setup` 完了後に `make restart` を実行してください。

5. Git hooks を有効化します。

```shell
make setup-git-hooks
```

Git hooks を有効化すると、コミット前に `make rubocop`、push 前に `make minitest` が実行されます。

### サービス管理

```shell
make shell    # devbox シェルに入る
make up       # PostgreSQL / Rails / Solid Queue / JS watcher / CSS watcher をバックグラウンド起動
make tui      # process-compose の TUI で起動
make down     # devbox サービスを停止
make status   # サービス状態を確認
make ps       # make status のエイリアス
make restart  # devbox サービスを再起動
make logs     # Rails development.log を tail
make fix-pg   # 古い postmaster.pid を削除して PostgreSQL を再起動
make versions # Ruby / Rails / Node / Yarn / PostgreSQL / Bundler のバージョンを表示
```

`make up` 後、管理画面は http://localhost:3000/admin で開けます。ヘルスチェックは http://localhost:3000/up です。

Rails サーバーだけを起動したい場合は次を使います。

```shell
make server
```

管理画面の非同期操作を処理するには、別ターミナルで Solid Queue worker も起動します。

```shell
make jobs
```

### Rails / DB 操作

```shell
make console            # Rails コンソール
make console-sandbox    # サンドボックスモードの Rails コンソール
make bundle             # bundle install

make dbinit             # DB を drop して setup
make dbconsole          # DB コンソール
make migrate            # マイグレーション実行
make migrate-redo       # 最後のマイグレーションをやり直し
make rollback           # ロールバック
make dbseed             # db/seeds.rb を実行
make db-dump            # tmp/data/dev.bak に DB バックアップ
make db-restore         # tmp/data/dev.bak から DB リストア
```

### 原作・原曲データ

```shell
make update-originals-all   # 原作・原曲データを upsert
make seed-originals         # 原作データだけを truncate して再投入
make seed-original-songs    # 原曲データだけを truncate して再投入
make seed-originals-all     # 原作・原曲データを truncate して再投入
```

### テスト・Lint・アセット

```shell
make minitest               # Minitest を実行
make js-test                # JavaScript テストを実行
make minitest-assets        # Minitest 後に CSS / JS アセットをビルド
make rubocop                # RuboCop を実行
make rubocop-correct        # RuboCop の安全な自動修正
make rubocop-correct-all    # RuboCop の全自動修正

yarn build                  # JavaScript をビルド
yarn build:css              # Tailwind CSS をビルド
yarn test:js                # JavaScript テストを実行
yarn playwright-cli         # Playwright CLI
```

### データ入出力・保守

```shell
make export-for-algolia      # Algolia 向け JSON 出力
make check-algolia           # Algolia との差分確認
make export-karaoke-songs    # カラオケ楽曲 TSV 出力
make import-karaoke-songs    # カラオケ楽曲 TSV インポート
make export-display-artists  # アーティスト TSV 出力
make import-display-artists  # アーティスト TSV インポート
make import-touhou-music     # 東方楽曲データインポート
make import-touhou-music-slim # 東方楽曲データの軽量インポート
make stats                   # 統計情報生成
```

### JOYSOUND ミュージックポスト保守

```shell
make check-expired-joysound  # 配信期限切れの確認
make delete-expired-joysound # 配信期限切れの削除
```

## プロジェクト構成

```text
app/
  controllers/admin/   # 管理画面 controller
  models/              # Rails models と admin 用 registry / workflow
  policies/            # Pundit policies
  services/            # スクレイピング、URL 検証、進捗管理など
  views/admin/         # 管理画面 views
  javascript/          # 管理画面 JavaScript
  assets/              # Tailwind CSS と build 出力
db/
  fixtures/            # TSV fixtures
  seeds/               # 初期データ投入タスク
lib/
  *.rb                 # import / export / maintenance scripts
test/                  # Minitest
```

## 開発時の注意

- 外部サイト取得、Algolia 操作、インポート、削除を伴う保守処理は失敗やデータ変更を前提に、実行結果とログを確認してください。
- API キーなどの秘密情報は `.env`、Rails credentials、環境変数で管理し、リポジトリへコミットしないでください。
- UI を変更した場合は、ローカルサーバー上で管理画面の対象フローを確認してください。
- コミットは Conventional Commits 形式を使い、説明は日本語で書いてください。

<details>
<summary><strong>Docker 環境（代替手段）</strong></summary>

Docker 環境を使う場合は、コマンドに `docker-` プレフィックスを付けて実行します。

### 初回セットアップ

```shell
make docker-init
```

### サーバー起動

```shell
make docker-server
```

### Docker コマンド

```shell
make docker-up
make docker-down
make docker-console
make docker-console-sandbox
make docker-bundle
make docker-dbinit
make docker-dbconsole
make docker-migrate
make docker-migrate-redo
make docker-rollback
make docker-dbseed
make docker-update-originals-all
make docker-seed-originals
make docker-seed-original-songs
make docker-seed-originals-all
make docker-minitest
make docker-rubocop
make docker-rubocop-correct
make docker-rubocop-correct-all
make docker-bash
make docker-export-for-algolia
make docker-check-algolia
make docker-export-karaoke-songs
make docker-import-karaoke-songs
make docker-export-display-artists
make docker-import-display-artists
make docker-import-touhou-music
make docker-import-touhou-music-slim
make docker-check-expired-joysound
make docker-delete-expired-joysound
make docker-stats
make docker-db-dump
make docker-db-restore
```

### Docker から devbox へ移行

```shell
make docker-db-dump
make docker-down
devbox shell
make up
createdb touhou_karaoke_admin_development
make db-restore
make bundle
make migrate
```

### devbox で問題が発生した場合

```shell
make down
make docker-up
make docker-server
```

</details>

## コマンド一覧

```shell
make help
```
