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

- Ruby 4.0.6
- Rails 8.1.3.1
- PostgreSQL 18.4
- Solid Queue 1.6
- Pundit
- Ransack
- Algolia Search
- Tailwind CSS 4 / daisyUI 5
- esbuild
- Node.js 24 LTS / Yarn 4.18.0
- mise / Task
- Minitest
- RuboCop / rubocop-rails / rubocop-performance

## 開発環境

このプロジェクトは **devbox** を標準の開発環境、**Task** をプロジェクトコマンドの標準ランナーとして使います。Task CLIのバージョンは `mise.toml` で管理しています。通常の開発・テスト・Lint・DB 操作は `task` 経由で実行してください。

`Makefile` は既存のスクリプトや開発者向けの互換入口として残しています。`make <task>` はmise管理のTaskへ委譲するため、新しい手順では `task <task>` を使用してください。

Node.js は24系LTSを対象にしています。CIは24.19.0を固定し、Devboxはカタログで提供される`nodejs-slim` 24.18.1を使います。YarnはCorepack 0.35.0経由で4.18.0を使用し、依存関係の再現には`yarn install --immutable`を使います。

Apple Silicon macOSと`aarch64-linux` / `x86_64-linux`は`devbox.lock`の対象です。

### devbox のインストール

```shell
curl -fsSL https://get.jetify.com/devbox | bash
```

### mise のインストール

miseをインストールしてシェルを有効化します。zshの場合は次の設定を一度だけ実行してください。

```shell
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
```

シェルを再起動した後、リポジトリの設定を信頼してTask CLIをインストールします。

```shell
mise trust
mise install
```

miseをシェルで有効化していない場合は、`mise exec -- task <task>` の形式で実行できます。

### 初回セットアップ

1. 環境変数ファイルを作成します。

```shell
cp .env.devbox.template .env
```

Algolia を使う処理を実行する場合は、`.env` の `ALGOLIA_APPLICATION_ID`、`ALGOLIA_API_KEY`、`ALGOLIA_INDEX_NAME` を実値に変更してください。

管理画面に Basic 認証を付けたい場合は、`.env` に `TOUHOU_KARAOKE_ADMIN_BASIC_AUTH_USERNAME` と `TOUHOU_KARAOKE_ADMIN_BASIC_AUTH_PASSWORD` を両方設定してください。未設定の場合は認証なしで従来通り動作します。

2. 必要に応じてdevboxシェルに入ります。

```shell
task shell
```

3. PostgreSQL と開発用プロセスを起動します。

```shell
task up
```

4. 依存関係と DB を準備します。

```shell
task setup
```

初回は依存関係のインストール前に Rails / JS / CSS プロセスが一時的に失敗することがあります。その場合は `task setup` 完了後に `task restart` を実行してください。

5. Git hooks を有効化します。

```shell
task setup-git-hooks
```

Git hooks を有効化すると、コミット前に `task rubocop`、push 前に `task minitest` が実行されます。

### サービス管理

```shell
task shell    # devbox シェルに入る
task up       # PostgreSQL / Rails / Solid Queue / JS watcher / CSS watcher をバックグラウンド起動
task tui      # process-compose の TUI で起動
task down     # devbox サービスを停止
task status   # サービス状態を確認
task ps       # task status のエイリアス
task restart  # devbox サービスを再起動
task logs     # Rails development.log を tail
task fix-pg   # 古い postmaster.pid を削除して PostgreSQL を再起動
task versions # Ruby / Rails / Node / Yarn / PostgreSQL / Bundler のバージョンを表示
```

`task up` 後、通常は管理画面を http://localhost:3000/admin、ヘルスチェックを http://localhost:3000/up で開けます。3000番ポートが使用中の場合は、空いているポート（例: 3001）を自動選択し、起動先URLを表示します。現在のポートは `task status` でも確認できます。ポートを指定する場合は `DEVBOX_RAILS_PORT=3100 task up` とします。

Rails サーバーだけを起動したい場合は次を使います。

```shell
task server
```

管理画面の非同期操作を処理するには、別ターミナルで Solid Queue worker も起動します。

```shell
task jobs
```

### Rails / DB 操作

```shell
task console            # Rails コンソール
task console-sandbox    # サンドボックスモードの Rails コンソール
task bundle             # bundle install

task dbinit             # DB を drop して setup
task dbconsole          # DB コンソール
task migrate            # マイグレーション実行
task migrate-redo       # 最後のマイグレーションをやり直し
task rollback           # ロールバック
task dbseed             # db/seeds.rb を実行
task db-dump            # tmp/data/dev.bak に DB バックアップ
task db-restore         # tmp/data/dev.bak から DB リストア
```

### 原作・原曲データ

```shell
task update-originals-all   # 原作・原曲データを upsert
task seed-originals         # 原作データだけを truncate して再投入
task seed-original-songs    # 原曲データだけを truncate して再投入
task seed-originals-all     # 原作・原曲データを truncate して再投入
```

### テスト・Lint・アセット

```shell
task minitest               # Minitest を実行
task js-test                # JavaScript テストを実行
task minitest-assets        # Minitest 後に CSS / JS アセットをビルド
task rubocop                # RuboCop を実行
task rubocop-correct        # RuboCop の安全な自動修正
task rubocop-correct-all    # RuboCop の全自動修正

task build                  # JavaScript をビルド
task build-css              # Tailwind CSS をビルド
task js-test                # JavaScript テストを実行
task playwright-cli         # Playwright CLI
```

### データ入出力・保守

```shell
task export-for-algolia      # Algolia 向け JSON 出力
task check-algolia           # Algolia との差分確認
task export-karaoke-songs    # カラオケ楽曲 TSV 出力
task import-karaoke-songs    # カラオケ楽曲 TSV インポート
task export-display-artists  # アーティスト TSV 出力
task import-display-artists  # アーティスト TSV インポート
task import-touhou-music     # 東方楽曲データインポート
task import-touhou-music-slim # 東方楽曲データの軽量インポート
task stats                   # 統計情報生成
task data-duplicate-report   # unique index 追加前の重複データ確認
```

### JOYSOUND ミュージックポスト保守

```shell
task check-expired-joysound  # 配信期限切れの確認
task delete-expired-joysound # 配信期限切れの削除
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

## コマンド一覧

```shell
task help
```
