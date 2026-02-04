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

このプロジェクトは **devbox** を使用した開発を推奨しています。devboxはローカル実行で高速・軽量な開発体験を提供します。

> **Note**: Docker環境も利用可能です。詳細は[Docker環境（代替手段）](#docker環境代替手段)を参照してください。

## セットアップ

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
make up
```

3. セットアップを実行（bundle install, yarn install, DB準備）

```shell
make setup
```

### 日常の開発コマンド

#### サービス管理

```shell
make shell    # devboxシェルに入る
make up       # PostgreSQLを起動
make down     # PostgreSQLを停止
make status   # サービス状態を確認
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

---

<details>
<summary><strong>Docker環境（代替手段）</strong></summary>

Docker環境を使いたい場合は、コマンドに `docker-` プレフィックスを付けて実行します。

### 初回の環境構築

```shell
make docker-init
```

### サーバーの起動

```shell
make docker-server
```

### Dockerコマンド一覧

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

### Dockerからdevboxへの移行

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
make up
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

### devboxで問題が発生した場合

devbox環境で問題が発生した場合、Docker環境に戻すことができます：

```shell
make down
make docker-up
make docker-server
```

</details>

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

## JOYSOUND(うたスキ) 配信期限切れチェック・削除

Algolia上のJOYSOUND(うたスキ)レコードから配信期限切れのものを検出・削除する。

```shell
make check-expired-joysound  # 配信期限切れチェック（表示のみ）
make delete-expired-joysound # 配信期限切れ削除（確認プロンプトあり）
```
