# CLAUDE.md

東方カラオケ検索管理サイト - DAM・JOYSOUNDの東方アレンジ楽曲を管理するRailsアプリケーション。

## クイックスタート

```bash
devbox shell          # 環境に入る
make up               # PostgreSQL + Rails サーバー起動
```

http://localhost:3000 でアクセス可能。

## 技術スタック

- Ruby 3.4.4 / Rails 8.0.2 / PostgreSQL 16
- devbox (Nix ベース開発環境)
- Avo (管理画面)
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
- Avo アクション: `app/avo/actions/`

## 管理画面

Avo でルートパス (`/`) にマウント。
- リソース: `app/avo/resources/`
- コントローラー: `app/controllers/avo/`
