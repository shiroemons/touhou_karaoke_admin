# 東方カラオケ検索管理サイト

## 機能

### カラオケ楽曲管理
- **DAM・JOYSOUND対応**: 両カラオケシステムの東方アレンジ楽曲を一元管理
- **楽曲情報の自動収集**: Web スクレイピングによる最新楽曲情報の取得
- **原曲との紐付け**: 東方原作の楽曲との関連付け管理
- **機種別配信状況**: カラオケ機種ごとの配信状況を追跡

### データ管理機能
- **アーティスト管理**: サークル（同人音楽グループ）情報との紐付け
- **楽曲メタデータ**: YouTube、Apple Music、Spotify などの配信 URL 管理
- **配信期限管理**: JOYSOUND の楽曲配信期限の追跡と更新

### 検索・出力機能
- **Algolia 連携**: 高速な楽曲検索のための検索エンジン連携
- **データエクスポート**: カラオケ楽曲情報の CSV/JSON 形式での出力
- **原曲不明楽曲の抽出**: 原曲との紐付けが未完了の楽曲リスト生成

### 管理画面（Avo）
- **直感的な UI**: Avo を使用した使いやすい管理インターフェース
- **一括操作**: 複数楽曲の一括更新・データ取得
- **ダッシュボード**: 楽曲数や収集状況の可視化

## 開発環境

このプロジェクトは2つの開発環境をサポートしています：

| 環境 | 特徴 | コマンドプレフィックス |
|------|------|------------------------|
| **devbox** (推奨) | ローカル実行、高速、軽量 | `make <command>` |
| **Docker** | コンテナ隔離、既存環境との互換性 | `make docker-<command>` |

---

## devbox環境（推奨）

### devboxのインストール

```shell
curl -fsSL https://get.jetify.com/devbox | bash
```

### 初回の環境構築

1. devbox環境を初期化

```shell
devbox shell
```

2. PostgreSQLサービスを起動

```shell
make services-start
```

3. セットアップを実行（bundle install, yarn install, DB準備）

```shell
make init
```

### 日常の開発コマンド

#### サービス管理

```shell
make shell              # devboxシェルに入る
make services-start     # PostgreSQLを起動
make services-stop      # PostgreSQLを停止
make services-status    # サービス状態を確認
```

#### サーバーの起動

```shell
make server
```

実行すると http://localhost:3000 でアクセスできる。

#### コンソールの起動

```shell
make console            # Railsコンソール
make console-sandbox    # サンドボックスモード
```

#### DB関連

```shell
make dbinit       # DBを初期化 (drop and setup)
make dbconsole    # DBコンソール
make migrate      # マイグレーション実行
make migrate-redo # 最後のマイグレーションをやり直し
make rollback     # ロールバック
make dbseed       # シードデータ投入
make db-dump      # DBバックアップ (tmp/data/dev.bak)
make db-restore   # DBリストア
```

#### bundle install

```shell
make bundle
```

#### テストの実行

```shell
make minitest
```

#### Rubocop

```shell
make rubocop            # リント実行
make rubocop-correct    # 自動修正
make rubocop-correct-all # 全て自動修正
```

#### データエクスポート/インポート

```shell
make export-for-algolia      # Algolia向けJSON出力
make export-karaoke-songs    # カラオケ楽曲出力
make import-karaoke-songs    # カラオケ楽曲インポート
make export-display-artists  # アーティスト出力
make import-display-artists  # アーティストインポート
make import-touhou-music     # 東方楽曲データインポート
make stats                   # 統計情報生成
```

#### JOYSOUND(うたスキ) 管理

```shell
make check-expired-joysound  # 配信期限切れチェック
make delete-expired-joysound # 配信期限切れ削除
```

### Dockerからdevboxへの移行手順

既存のDocker環境からdevbox環境に移行する場合：

1. Dockerでデータベースをバックアップ

```shell
make docker-db-dump
```

2. Dockerを停止

```shell
make docker-down
```

3. devbox環境を準備

```shell
devbox shell
make services-start
```

4. データベースを作成してリストア

```shell
createdb touhou_karaoke_admin_development
make db-restore
```

5. セットアップを完了

```shell
make bundle
make migrate
```

### devboxでの問題発生時のロールバック

devbox環境で問題が発生した場合、Docker環境に戻すことができます：

```shell
devbox services stop
make docker-up
make docker-server
```

---

## Docker環境

Docker環境を使用する場合は、コマンドに `docker-` プレフィックスを付けます。

### 初回の環境構築

```shell
make docker-init
```

### サーバーの起動

```shell
make docker-server
```

### その他のDockerコマンド

```shell
make docker-up               # コンテナ起動
make docker-down             # コンテナ停止
make docker-console          # Railsコンソール
make docker-console-sandbox  # サンドボックスモード
make docker-bundle           # bundle install
make docker-dbinit           # DB初期化
make docker-dbconsole        # DBコンソール
make docker-migrate          # マイグレーション
make docker-rollback         # ロールバック
make docker-dbseed           # シードデータ投入
make docker-minitest         # テスト実行
make docker-rubocop          # Rubocop実行
make docker-bash             # bashシェル
make docker-db-dump          # DBバックアップ
make docker-db-restore       # DBリストア
```

---

## 利用可能なコマンド一覧

```shell
make help
```

---

## 情報収集方法

### DAM

```ruby
DamArtistUrl.fetch_dam_artist
DamSong.fetch_dam_songs
Song.fetch_dam_songs
```

### JOYSOUND

```ruby
JoysoundSong.fetch_joysound_song
Song.fetch_joysound_songs
DisplayArtist.fetch_joysound_artist
```

### JOYSOUND(うたスキ)

```ruby
JoysoundMusicPost.fetch_music_post
DisplayArtist.fetch_joysound_music_post_artist
JoysoundMusicPost.fetch_music_post_song_joysound_url
Song.fetch_joysound_music_post_song
Song.refresh_joysound_music_post_song
```

- 差分がある場合の確認方法
  - 原因は、アーティストが重複している可能性あり。

```ruby
JoysoundMusicPost.all.map { { title: _1.title } } - Song.music_post.map { { title: _1.title} }
```

## Algolia向けのJSONを生成

```shell
make export-for-algolia
```

## Algolia アップロード差分確認（Dry-Run）

ローカルの `tmp/karaoke_songs.json` と Algolia インデックスを比較し、差分を確認する。

```shell
# 基本実行
docker compose run --rm web bin/rails runner lib/check_algolia_upload.rb

# 詳細表示（変更内容を詳しく表示）
docker compose run --rm web bin/rails runner lib/check_algolia_upload.rb --verbose

# JSON形式で出力
docker compose run --rm web bin/rails runner lib/check_algolia_upload.rb --json

# 変更があるレコードのみをファイルに出力
docker compose run --rm web bin/rails runner lib/check_algolia_upload.rb --output-changes tmp/changes.json
```

### オプション

| オプション | 説明 |
|------------|------|
| `--json` | JSON形式で出力 |
| `--verbose` | 詳細表示 |
| `--show-unchanged` | 変更なしレコードのIDを出力 |
| `--output-changes FILE` | 変更ありレコードのみをFILEに出力 |
| `--no-color` | カラー出力を無効化 |

## JOYSOUND(うたスキ) 配信期限切れチェック・削除

Algolia上のJOYSOUND(うたスキ)レコードから配信期限切れのものを検出・削除する。

```shell
# 配信期限切れレコードのチェック（表示のみ）
make check-expired-joysound

# 配信期限切れレコードの削除（確認プロンプトあり）
make delete-expired-joysound
```

### 直接実行する場合

```shell
# 基本実行（表示のみ）
docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb

# 詳細表示（アーティスト・URL含む）
docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --verbose

# URLにアクセスして配信終了を確認
docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --verify --verbose

# JSON形式で出力
docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --json

# 削除実行（確認プロンプトあり）
docker compose run --rm web bin/rails runner lib/check_expired_joysound_utasuki.rb --delete
```

### オプション

| オプション | 説明 |
|------------|------|
| `--delete` | 実際に削除を実行（デフォルトは表示のみ） |
| `--verify` | URLにアクセスして配信終了を確認（404チェック） |
| `--verbose` | 詳細表示（アーティスト・URL含む） |
| `--json` | JSON形式で出力 |
| `--no-color` | カラー出力を無効化 |

## カラオケ楽曲出力

```shell
make export-karaoke-songs
```
