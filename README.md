# 東方カラオケ検索管理サイト

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

## カラオケ楽曲出力

```shell
make export-karaoke-songs
```