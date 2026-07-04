# CLAUDE.md

東方カラオケ検索管理サイト - DAM・JOYSOUNDの東方アレンジ楽曲を管理するRailsアプリケーション。

## クイックスタート

```bash
devbox shell          # 環境に入る
make up               # PostgreSQL + Rails サーバー起動
```

http://localhost:3000 でアクセス可能。

## 技術スタック

- Ruby 4.0.5 / Rails 8.1 / PostgreSQL 18
- devbox (Nix ベース開発環境)
- Algolia (検索)
- Ferrum (Webスクレイピング)

## 主要モデル

| モデル | 説明 |
|--------|------|
| Song | カラオケ楽曲（DAM, JOYSOUND, うたスキ） |
| DisplayArtist | アーティスト表示名 |
| Original | 東方原作 |
| OriginalSong | 原曲 |
| KaraokeDeliveryModel | カラオケ機種 |

## データ収集

- **DAM**: `DamArtistUrl`, `DamSong` モデル経由
- **JOYSOUND**: `JoysoundSong`, `JoysoundMusicPost` モデル経由
- 操作: `app/models/admin/operations/`

## 管理画面

独自の管理画面フレームワークをルートパス (`/`) にマウント。
- リソース定義: `app/models/admin/resources/`（`Admin::ResourceRegistry` に登録）
- コントローラー: `app/controllers/admin/`（一覧表示は `Admin::ResourcesController` + `Admin::ResourceIndexQuery`）
- 操作: `app/models/admin/operations/`
