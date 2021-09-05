# 東方カラオケ検索管理サイト

## 初期設定

### DB作成

```sh
bundle exec rails db:create
```

### DBマイグレーション

```sh
bundle exec rails db:migrate
```

### 初期データ登録

```sh
bundle exec rails db:seed
```

## プロセスマネージャー `hivemind` をインストール

```sh
brew install hivemind
```

### サーバー起動

```sh
hivemind Procfile.dev
```

- http://localhost:3000/

## 情報収集方法

### DAM

```ruby
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
bin/rails r lib/export_songs.rb
```
