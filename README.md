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

## 使い方

### 初回の環境構築

Dockerイメージを作成して、 `bin/setup` を実行する。

```shell
make init
```

### bundle install

```shell
make bundle
```

### DB関連

- DB init
  ```shell
  make dbinit
  ```

- DB console
  ```shell
  make dbconsole
  ```

- DB migrate
  ```shell
  make migrate
  ```

- DB rollback
  ```shell
  make rollback
  ```

- DB seed
  ```shell
  make dbseed
  ```

### サーバーの起動

```shell
make server
```

実行すると http://localhost:3000 でアクセスできる。

### コンソールの起動

```shell
make console
```

- sandbox
  ```shell
  make console-sandbox
  ```

### テストの実行

````shell
make minitest
````

### Rubocop

- rubocop
    ```shell
    make rubocop
    ```

- rubocop-correct
    ```shell
    make rubocop-correct
    ```

- rubocop-correct-all
    ```shell
    make rubocop-correct-all
    ```

### Railsコマンド

```shell
docker-compose run --rm web bin/rails -T
```

### 起動(docker compose up)

```shell
make start
```

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

## カラオケ楽曲出力

```shell
make export-karaoke-songs
```