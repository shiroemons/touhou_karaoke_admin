# 管理画面 DB index 監査メモ

最終更新: 2026-06-29

## 前提

- 破壊的変更を避けるため、このメモでは migration を追加しない。
- 現行の `db/schema.rb` と `app/models/admin/resources/*.rb` の検索、フィルタ、ソート、関連表示を突き合わせた。
- unique index は既存データの重複確認と cleanup 手順を通してから追加する。

## 既に index がある主要経路

| 用途 | 対象 |
| --- | --- |
| 管理画面変更履歴 | `admin_change_logs(resource_key, event, created_at)`, `admin_change_logs(resource_key, record_id, created_at)` |
| 非同期進捗の掃除 | `admin_operation_progresses(updated_at)` |
| 外部 URL 参照 | `dam_artist_urls(url)`, `dam_songs(url)`, `joysound_songs(url)`, `joysound_music_posts(url)`, `joysound_music_posts(joysound_url)` |
| 期限フィルタ | `joysound_music_posts(delivery_deadline_on)` |
| 関連 ID | `dam_songs(display_artist_id)`, `songs(display_artist_id)`, `original_songs(original_code)`, 各 join table の単体外部キー |
| 管理画面の配信種別絞り込み | `songs(karaoke_type, created_at)`, `display_artists(karaoke_type, name)` |
| 表示順 | `karaoke_delivery_models(order)` |
| 既存 unique 制約 | `karaoke_delivery_models(name, karaoke_type)`, `songs_karaoke_delivery_models(song_id, karaoke_delivery_model_id)` |

## 追加候補

| 優先度 | 候補 | 理由 | 事前確認 |
| --- | --- | --- | --- |
| 中 | 外部 URL index の unique 化 | `dam_songs.url`, `joysound_songs.url`, `joysound_music_posts.url` は一意候補。現在は非 unique。 | 外部サイト側で同一 URL が別データを表す例外がないか確認し、重複データ確認後に個別 migration 化する。 |
| 中 | `song_with_dam_ouchikaraokes(url)`, `song_with_joysound_utasukis(url)` | 管理画面で URL 表示と外部連携結果の突合が増える場合に有効。現状は `song_id` のみ。 | 実際の検索・検証経路で URL 条件が使われることを確認する。 |
| 低 | `pg_trgm` + GIN index for `name` / `title` / `url` | 管理画面検索は `%keyword%` の `LIKE` なので通常 btree は効きにくい。対象は `songs.title`, `display_artists.name`, `circles.name`, `originals.title`, `original_songs.title` など。 | レコード数と検索遅延が問題化してから、PostgreSQL拡張と explain で効果を確認する。 |

## 追加済み

| 対象 | 内容 |
| --- | --- |
| `display_artists_circles(display_artist_id, circle_id)` | 2026-06-30 に事前重複チェック付き unique index を追加した。 |
| `songs_original_songs(song_id, original_song_code)` | 2026-06-30 に事前重複チェック付き unique index を追加した。 |
| `dam_artist_urls(url)` | 2026-06-30 に重複行を手動確認・整理した後、事前重複チェック付き unique index を追加した。 |

## 重複確認結果

2026-06-29 に `devbox run -- make data-duplicate-report` を実行した結果、`dam_artist_urls.url` に重複が 1 組見つかった。

```text
[dam_artist_urls] url
  url="https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=141159", duplicate_count=2
```

2026-06-30 時点の影響確認では、同 URL に紐づく `DisplayArtist` は 1 件、関連 `DamSong` は 17 件だった。`dam_artist_urls` は外部キーで参照されていないため、重複解消時も `DisplayArtist` と `DamSong` は削除しない。

破壊的な自動削除は行わず、まず `make data-duplicate-impact-report` で canonical 候補、重複行 ID、関連件数を確認する。このため、外部 URL の unique index 化は `dam_artist_urls.url` の重複を安全に整理するまで保留する。他の `DataIntegrity::DuplicateFinder::DEFAULT_CHECKS` 対象では、この実行時点で重複は報告されていない。

## 今は追加しない

- `karaoke_type` 単体 index: `songs` と `display_artists` は既に複合 index の先頭列でカバーされる。
- `created_at` 単体 index の追加: 管理画面の default order が必要な主要外部取得系には追加済み。
- 即時の unique migration: 重複がある状態で deploy すると失敗するため、必ず dry-run と cleanup を先に行う。

## 次の実装単位

1. `make data-duplicate-impact-report` で `dam_artist_urls.url` の重複影響を確認する。
2. 外部 URL unique 化可否をテーブルごとに確認する。
3. 必要な migration は 1 テーブルまたは 1 関連ごとに分け、追加前に重複検出テストを用意する。
