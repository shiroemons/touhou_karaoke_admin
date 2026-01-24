# Algolia Browse API ガイド

このドキュメントは、東方カラオケ検索で使用しているAlgolia検索インデックスのBrowse API利用方法とデータ構造をまとめたものです。

> **Note:** このガイドで説明するのは主にBrowse APIです。Browse APIは全件取得やバッチ処理に適しており、Browse権限を持つAPI Keyで利用可能です。

## 接続設定

### 認証情報

```ruby
ALGOLIA_APP_ID = ""  # Application ID
ALGOLIA_API_KEY = ""  # Browse権限を持つAPI Key
ALGOLIA_INDEX_NAME = "touhou_karaoke"
```

> **Note:** API Keyは用途に応じた権限を持つものを使用してください。Browse APIを使用する場合は、Browse権限（`browse`）が必要です。

### クライアント初期化

```ruby
require "algolia"

client = Algolia::SearchClient.create(ALGOLIA_APP_ID, ALGOLIA_API_KEY)
```

## Browse API

### 概要

Browse APIは、インデックス内の全レコードを取得するためのAPIです。以下の特徴があります:

- **用途**: 全件取得、バッチ処理、データ同期
- **認証**: Browse権限（`browse`）を持つAPI Keyが必要
- **制限**: ページネーションを自動処理し、全レコードを取得可能

### 基本的な使い方

```ruby
records = []
client.browse_objects(
  ALGOLIA_INDEX_NAME,
  {
    filters: 'karaoke_type:"DAM"',
    attributesToRetrieve: %w[objectID title url song_number updated_at_i]
  }
).each do |record|
  props = record.additional_properties
  records << {
    id: record.algolia_object_id,
    title: props[:title],
    url: props[:url],
    song_number: props[:song_number],
    updated_at_i: props[:updated_at_i]
  }
end
```

### フィルタリング

karaoke_typeでフィルタリングする際は、値をダブルクォートで囲む必要があります。

```ruby
# DAM
filters: 'karaoke_type:"DAM"'

# JOYSOUND
filters: 'karaoke_type:"JOYSOUND"'

# JOYSOUND(うたスキ) - 括弧を含む場合もそのまま
filters: 'karaoke_type:"JOYSOUND(うたスキ)"'
```

---

## Search API（参考）

Search APIはキーワード検索用のAPIです。Browse APIとは異なる権限が必要です。

```ruby
response = client.search_single_index(
  ALGOLIA_INDEX_NAME,
  Algolia::Search::SearchParamsObject.new(
    query: "検索クエリ",
    filters: 'karaoke_type:"DAM"'
  )
)

response.hits.each do |hit|
  props = hit.additional_properties
  puts props[:title]
end
```

**注意:**
- `search_single_index` はSearch権限（`search`）を持つAPI Keyが必要です
- バッチ処理や全件取得には Browse API を使用してください
- Search APIは検索機能向けであり、データ同期には不向きです

### 取得属性の指定

必要な属性のみを取得することでパフォーマンスが向上します。

```ruby
attributesToRetrieve: %w[objectID title url song_number updated_at_i]
```

---

## データ構造

### 共通フィールド

全てのkaraoke_typeで共通のフィールド:

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `objectID` | String (UUID) | 一意識別子（SongモデルのID） |
| `title` | String | 曲名 |
| `reading_title` | String | 曲名の読み（カタカナ、空の場合あり） |
| `display_artist` | Object | アーティスト情報 |
| `original_songs` | Array | 原曲情報 |
| `karaoke_type` | String | カラオケ種別 |
| `karaoke_delivery_models` | Array | 対応機種 |
| `circle` | Object | サークル情報 |
| `url` | String | カラオケサービスの楽曲URL |
| `updated_at_i` | Integer | 更新日時（Unix timestamp） |
| `videos` | Array | 動画情報（YouTube, ニコニコ動画） |
| `touhou_music` | Array | 音楽配信サービスURL |

### display_artist オブジェクト

```json
{
  "name": "サークル名/アーティスト名",
  "reading_name": "ヨミガナ（カタカナ）",
  "reading_name_hiragana": "よみがな（ひらがな）",
  "karaoke_type": "DAM",
  "url": "https://..."
}
```

### original_songs 配列

```json
[
  {
    "title": "原曲名",
    "original": {
      "title": "東方紅魔郷　～ the Embodiment of Scarlet Devil.",
      "short_title": "東方紅魔郷"
    },
    "categories.lvl0": "01. Windows作品",
    "categories.lvl1": "01. Windows作品 > 06.0. 東方紅魔郷",
    "categories.lvl2": "01. Windows作品 > 06.0. 東方紅魔郷 > 03. 亡き王女の為のセプテット"
  }
]
```

### karaoke_delivery_models 配列

```json
[
  { "name": "LIVE DAM Ai", "karaoke_type": "DAM" },
  { "name": "JOYSOUND MAX GO", "karaoke_type": "JOYSOUND" }
]
```

### circle オブジェクト

```json
{
  "name": "サークル名"
}
```

### videos 配列

```json
[
  { "type": "YouTube", "url": "https://www.youtube.com/watch?v=xxx", "id": "xxx" },
  { "type": "ニコニコ動画", "url": "https://www.nicovideo.jp/watch/sm123", "id": "sm123" }
]
```

### touhou_music 配列

```json
[
  { "type": "Apple Music", "url": "https://music.apple.com/..." },
  { "type": "YouTube Music", "url": "https://music.youtube.com/..." },
  { "type": "Spotify", "url": "https://open.spotify.com/..." },
  { "type": "LINE MUSIC", "url": "https://music.line.me/..." }
]
```

---

## カラオケメーカー別データ

### DAM

**レコード数:** 約1,400件

**固有フィールド:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `song_number` | String | リクエスト番号（例: "1211-47"） |
| `ouchikaraoke_url` | String | カラオケ@DAMのURL |

**URL形式:**
- 楽曲: `https://www.clubdam.com/karaokesearch/songleaf.html?requestNo=XXXX-XX`
- アーティスト: `https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=XXXXXX`
- おうちカラオケ: `https://www.clubdam.com/app/damtomo/karaokeAtDam/MusicDetail.do?contentsId=XXXXXXX`

**サンプルレコード:**

```json
{
  "objectID": "ddada03f-e2df-4574-8531-052defc58816",
  "title": "落ちた雫の水鏡",
  "reading_title": "オチタシズクノミズカガミ",
  "karaoke_type": "DAM",
  "url": "https://www.clubdam.com/karaokesearch/songleaf.html?requestNo=1211-47",
  "song_number": "1211-47",
  "ouchikaraoke_url": "https://www.clubdam.com/app/damtomo/karaokeAtDam/MusicDetail.do?contentsId=6125534",
  "updated_at_i": 1763194832
}
```

**対応機種例:**
- LIVE DAM WAO!
- LIVE DAM Ai
- カラオケ@DAM

---

### JOYSOUND

**レコード数:** 約2,000件

**固有フィールド:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `song_number` | String | 選曲番号（例: "822730"） |

**URL形式:**
- 楽曲: `https://www.joysound.com/web/search/song/XXXXXXX`
- アーティスト: `https://www.joysound.com/web/search/artist/XXXXXX`

**サンプルレコード:**

```json
{
  "objectID": "d0e0d95b-7ba5-4060-a2b5-fd0044861ad6",
  "title": "さかさまレジスタンス《本人映像》",
  "reading_title": "",
  "karaoke_type": "JOYSOUND",
  "url": "https://www.joysound.com/web/search/song/1118575",
  "song_number": "822730",
  "updated_at_i": 1754661005
}
```

**対応機種例:**
- JOYSOUND X1
- JOYSOUND MAX GO
- JOYSOUND MAX2
- JOYSOUND MAX
- JOYSOUND f1
- JOYSOUND 響Ⅱ

---

### JOYSOUND(うたスキ)

**レコード数:** 約130件

うたスキ ミュージックポストから投稿された楽曲。配信期限があります。

**固有フィールド:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `delivery_deadline_date` | String | 配信期限（例: "2026/03/05"） |
| `delivery_deadline_date_i` | Integer | 配信期限（Unix timestamp） |
| `musicpost_url` | String | ミュージックポストのURL |

**URL形式:**
- 楽曲: `https://www.joysound.com/web/search/song/XXXXXXX`
- ミュージックポスト: `https://musicpost.joysound.com/music/musicId:XXXXX`
- アーティスト: `https://www.joysound.com/web/search/artist/XXXXXX`

**サンプルレコード:**

```json
{
  "objectID": "23cd1180-2b2d-4ebe-81d0-7af31ed03589",
  "title": "パーフェクトエレガントとミステリアスシークレット",
  "reading_title": "",
  "karaoke_type": "JOYSOUND(うたスキ)",
  "url": "https://www.joysound.com/web/search/song/649292",
  "delivery_deadline_date": "2026/03/05",
  "delivery_deadline_date_i": 1772668800,
  "musicpost_url": "https://musicpost.joysound.com/music/musicId:25121",
  "updated_at_i": 1759642560
}
```

**対応機種例:**
- JOYSOUND X1
- JOYSOUND MAX GO
- JOYSOUND MAX2
- JOYSOUND MAX
- JOYSOUND f1
- JOYSOUND 響Ⅱ

---

## コード例

### ローカルDBとの比較

```ruby
require "algolia"

ALGOLIA_APP_ID = ""
ALGOLIA_API_KEY = ""
ALGOLIA_INDEX_NAME = "touhou_karaoke"

client = Algolia::SearchClient.create(ALGOLIA_APP_ID, ALGOLIA_API_KEY)

# Algoliaからレコード取得
algolia_records = []
client.browse_objects(
  ALGOLIA_INDEX_NAME,
  {
    filters: 'karaoke_type:"DAM"',
    attributesToRetrieve: %w[objectID title url song_number updated_at_i]
  }
).each do |record|
  props = record.additional_properties
  algolia_records << {
    "objectID" => record.algolia_object_id,
    "title" => props[:title],
    "url" => props[:url],
    "song_number" => props[:song_number],
    "updated_at_i" => props[:updated_at_i]
  }
end

# ローカルDBのレコード取得
local_songs = Song.dam.index_by { |s| "#{s.title}|||#{s.url}|||#{s.song_number}" }

# マッチング
algolia_records.each do |record|
  key = "#{record['title']}|||#{record['url']}|||#{record['song_number']}"
  local_song = local_songs[key]

  if local_song
    if local_song.id == record["objectID"]
      # ID一致
    else
      # ID不一致 - 更新が必要
    end
  else
    # Algoliaのみ存在
  end
end
```

### タイムスタンプの変換

Algoliaの `updated_at_i` はUnix timestampです。

```ruby
# Unix timestamp → Time
timestamp = Time.at(record["updated_at_i"])
# => 2025-08-08 13:50:05 +0000

# ISO8601形式
timestamp.iso8601
# => "2025-08-08T13:50:05+00:00"
```

### ID更新（外部キー制約対応）

SongのIDを更新する際は、外部キー制約を一時的に無効化する必要があります。

```ruby
ActiveRecord::Base.transaction do
  conn = ActiveRecord::Base.connection

  # 外部キー制約を一時的に無効化
  conn.execute("SET session_replication_role = 'replica';")

  # Song ID更新
  conn.execute("UPDATE songs SET id = '#{new_id}', created_at = '#{timestamp.iso8601}', updated_at = '#{timestamp.iso8601}' WHERE id = '#{old_id}'")

  # 関連テーブル更新
  conn.execute("UPDATE songs_karaoke_delivery_models SET song_id = '#{new_id}' WHERE song_id = '#{old_id}'")
  conn.execute("UPDATE songs_original_songs SET song_id = '#{new_id}' WHERE song_id = '#{old_id}'")
  conn.execute("UPDATE song_with_dam_ouchikaraokes SET song_id = '#{new_id}' WHERE song_id = '#{old_id}'")
  conn.execute("UPDATE song_with_joysound_utasukis SET song_id = '#{new_id}' WHERE song_id = '#{old_id}'")

  # 外部キー制約を再有効化
  conn.execute("SET session_replication_role = 'origin';")
end
```

---

## インデックス設定（参考）

ローカルDBからAlgoliaへのインデックス登録は `AlgoliaSearchable` concernで設定されています。

**ファイル:** `app/models/concerns/algolia_searchable.rb`

**除外条件:**
- `original_songs` が空のレコード
- 原曲が「オリジナル」または「その他」のレコード

```ruby
def deleted?
  return true if original_songs.blank?

  original_song_titles = original_songs.map(&:title)
  original_song_titles.include?("オリジナル") || original_song_titles.include?("その他")
end
```

---

## 注意事項

1. **API Key の権限**: `browse_objects` にはBrowse権限、`search_single_index` にはSearch権限が必要です。API Keyの権限設定を確認してください。
2. **レート制限**: 大量のリクエストを送る場合はAlgoliaのレート制限に注意してください。
3. **配信期限切れデータ**: JOYSOUND(うたスキ)には配信期限切れのレコードが残っている場合があります。ローカルDBと比較する際は注意が必要です。
4. **文字エンコーディング**: 日本語を含むフィルタ条件はそのまま使用可能です。
