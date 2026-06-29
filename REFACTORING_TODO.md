# リファクタリング TODO リスト

最終更新: 2026-06-29

このドキュメントは、現在のコードベースで次に着手すべきリファクタリングを優先度順に整理する。完了済みの履歴は残しつつ、今後の作業は独自管理画面、非同期処理、外部サイト取得処理の保守性を中心に進める。

## 現状サマリー

- 管理画面は Avo 依存から Rails 標準の Controller / View / Policy ベースへ移行済み。
- Web スクレイピング、並列処理、配信機種管理、Song モデルの責務分割は実施済み。
- 管理画面アクションは Active Job + Solid Queue で非同期実行できる状態。
- 新しい肥大化ポイントは `Admin::ResourcesController`、管理画面 JavaScript のバルク編集 UI、JOYSOUND ミュージックポスト処理、モデルに残っている外部サイト取得処理。

## 優先度: 高

### 1. `Admin::ResourceRegistry` の分割

**問題点**: リソース定義のファイル分割は進んだが、`ResourceRegistryDefinitions` に共通フィルタ DSL と登録順が残っている。`ResourceRegistry` 本体は薄くなったため、次は定義の検証と追加時の安全性を上げる。

- [x] リソース定義を `app/models/admin/resources/*.rb` へ分割する。
- [x] フィールド、フィルタ、操作定義の builder を独立クラスまたは concern に切り出す。
- [x] 長文の操作説明を `config/locales/admin.ja.yml` または専用定義ファイルへ移す。
- [x] `ResourceRegistry` は登録と参照だけを担当する薄いクラスにする。
- [x] リソース定義の単体テストを追加し、必須属性、検索対象、操作キーの重複を検出する。
- [x] 共通フィルタ DSL を小さな module に切り出し、`ResourceRegistryDefinitions` は登録順と include だけに近づける。

**完了条件**:

- `ResourceRegistry` 本体が登録・参照・ナビゲーション構築に集中している。
- リソース追加時に既存ファイルの巨大な差分が発生しない。
- 全リソースの index / show / operation が既存通り動作する。

### 2. `Admin::OperationRunner` の責務分割

**問題点**: TSV 入出力、外部サイト取得、検証・削除、進捗更新、ダウンロード生成が 1 クラスに集約されている。

- [x] `Admin::Operations::BaseOperation` を作り、結果生成を共通化する。
- [x] TSV 入出力を `Admin::Operations::SongTsvOperation` などに分離する。
- [x] DisplayArtist 検証・削除系を専用 operation に分離する。
- [x] JOYSOUND ミュージックポスト系を専用 operation に分離する。
- [x] `OperationRunner` は operation の解決、実行、例外処理だけに限定する。
- [x] operation ごとの入力検証エラーを `ArgumentError` ではなく明示的なアプリケーション例外へ整理する。

**完了条件**:

- 新しい管理画面アクションを追加する時、`OperationRunner` へのメソッド追加が不要になる。
- 同期実行、非同期実行、ダウンロード生成の扱いが operation 単位で明確になる。
- 既存の TSV エクスポート / インポート、外部取得、検証・削除のテストが通る。

### 3. 管理画面 JavaScript の分割

**問題点**: 一覧更新、選択状態、操作モーダル、進捗 polling は分割済み。次の肥大化ポイントは `bulk_edit_controls.js` に集まっている原曲 picker、TSV paste、検索可能 select、関連 dialog。

- [x] `app/javascript/admin/infinite_scroll.js` を作成する。
- [x] 非同期 index 更新を navigation module へ分離する。
- [x] `app/javascript/admin/resource_selection.js` を作成する。
- [x] `app/javascript/admin/operation_modal.js` を作成する。
- [x] `app/javascript/admin/operation_progress.js` を作成する。
- [x] DOM selector を定数化し、同じ selector 文字列の重複を減らす。
- [x] 非同期処理失敗時の fallback 動作をテストで固定する。
- [x] `bulk_edit_controls.js` を原曲 picker、TSV paste、検索可能 select、関連 dialog に分ける。
- [x] バルク編集 UI の JavaScript テストを追加する。

**完了条件**:

- `application.js` は import と初期化だけを担当する。
- 管理画面操作の主要フローを system test またはブラウザ検証で確認できる。
- 非同期 index 更新後もモーダル、選択状態、フィルタ自動送信が再初期化される。

## 優先度: 中

### 4. Solid Queue 非同期処理の運用強化

**問題点**: 非同期実行は導入済みだが、失敗時の再実行、進捗レコードの保存期間、ジョブの可観測性がまだ最小限。

- [x] `admin_operation_progresses` の古いレコード削除方針を決める。
- [x] 失敗ジョブの再実行導線を管理画面に追加するか判断する。
- [x] ジョブ実行時の resource / operation をログに残す。
- [x] ジョブ実行時の actor / params summary をログに残す。
- [x] operation ごとの timeout と retry 方針を定義する。
- [x] 非同期化できない操作（ファイル upload、即時 download など）の制約をコード上で表現する。

### 5. 管理画面クエリと N+1 の確認

**問題点**: 汎用リソース管理の検索・フィルタ・ソートが増えたため、画面ごとのクエリ数が見えにくい。

- [x] `Admin::ResourcesController` の検索、フィルタ、ソート、ページング、部分描画を query/service object に切り出す。
- [x] 各リソースの index で発行されるクエリ数を確認する。
- [x] `count_association` ソートと association ソートの SQL をテストする。
- [x] `includes` と `left_outer_joins` の組み合わせで重複行が出ないことを確認する。
- [x] 一覧表示の件数カウント、無限スクロール、フィルタ適用後の総件数をテストする。
- [x] 必要な DB index を洗い出す。

### 6. JOYSOUND ミュージックポスト処理の整理

**問題点**: `JoysoundMusicPostManager` に取得、検証、期限更新、統合メンテナンス、エラー集計が集まっている。

- [ ] 取得、URL 検証、期限更新、統合メンテナンスを小さな service に分ける。
- [x] `ErrorReportService` の利用箇所を増やし、戻り値の `errors` 配列と二重管理しない。
- [ ] 進捗通知を `Admin::ProgressReporter` に寄せる。
- [x] `resumable:` オプションの利用実態を確認し、使わないなら削除する。
- [x] 大量処理時のスキップ、削除、更新件数をテストで固定する。

### 7. 外部サイト取得処理のテスト強化

**問題点**: スクレイピングや URL 確認は外部サイトの状態に左右されるが、テストがまだ限定的。

- [x] `UrlChecker` の成功、404、timeout、network error のテストを追加する。
- [ ] DAM / JOYSOUND scraper の HTML fixture を用意する。
- [ ] Ferrum を使う処理と HTTP だけで済む処理を分けてテストする。
- [ ] 外部サイト変更時に壊れやすい CSS selector の検証テストを追加する。
- [ ] `DamSong`、`JoysoundSong`、`DisplayArtist`、`DamArtistUrl` に残る Ferrum 直書き処理を service/scraper へ移す。

## 優先度: 低

### 8. ログとメトリクスの統一

- [ ] 外部取得、DB 更新、削除、スキップ、エラーを同じ形式でログ出力する。
- [ ] `Rails.logger.debug` / `info` / `warn` / `error` の使い分けを整理する。
- [x] 管理画面操作単位の operation id をログに含める。

### 9. `ResumableProcessor` の扱いを決める

**問題点**: `tmp/processing_states` への JSON 保存はローカル実行では便利だが、Solid Queue 導入後の本番運用と整合しにくい。

- [x] 現在利用されている実行経路を確認する。
- [x] 本番で不要と判断し、DB 永続化ではなく削除する方針にする。
- [x] 不要なら削除し、関連する `resumable:` オプションも取り除く。

### 10. 管理画面 UI の E2E カバレッジ追加

- [ ] `rack_test` の system test だけでなく、JavaScript が動く Selenium または Playwright の system test を追加する。
- [ ] フィルタ、ソート、ページング、無限スクロールの組み合わせを system test に追加する。
- [ ] 操作モーダルの入力必須制御、確認、非同期開始、進捗完了を検証する。
- [ ] 非同期 index 更新後にイベントハンドラが重複登録されないことを確認する。

### 11. DB 制約と index の見直し

- [x] 重複データの存在を確認し、非破壊の cleanup / dry-run 手順を用意する。
- [x] 外部 URL の一意性制約が必要なテーブルを確認する。
- [x] `dam_songs.url`、`joysound_songs.url`、`dam_artist_urls.url`、`joysound_music_posts.url` の unique index 化可否を確認する。
- [x] `display_artists_circles`、`songs_original_songs` の複合 unique index 化可否を確認する。
- [x] `karaoke_type`、期限日、外部 URL、関連 ID の index を確認する。
- [x] TSV import 時に不正な ID や重複原曲が混入した場合の扱いを明確にする。

## 完了済み

### 1. Web スクレイピング処理の共通化 (2025-06-01)

- [x] `BrowserManager` を作成し、Ferrum ブラウザ操作を統一管理した。
- [x] `Retryable` concern でリトライ処理を共通化した。
- [x] `Scrapers::BaseScraper`、`Scrapers::DamScraper`、`Scrapers::JoysoundScraper` を作成した。
- [x] Song モデルからスクレイピング処理を削減した。

### 2. 大量データ処理の最適化 (2025-06-01)

- [x] `ParallelProcessor` concern を作成した。
- [x] バッチ処理と進捗表示を共通化した。
- [x] `find_in_batches` を使ったメモリ効率の良い処理へ寄せた。

### 3. 配信機種管理の改善 (2025-06-01)

- [x] `DeliveryModelManager` service を作成した。
- [x] 配信機種 ID のキャッシュ戦略を改善した。
- [x] `name` + `karaoke_type` の重複作成を防ぐユニーク制約を追加した。

### 4. Song モデルの責務分割 (2025-06-01)

- [x] スクレイピング処理を scraper service へ移動した。
- [x] 並列処理を `ParallelProcessor` に移動した。
- [x] Algolia 検索関連を `AlgoliaSearchable` に切り出した。
- [x] カテゴリ関連メソッドを `Categorizable` に切り出した。

### 5. 定数の整理と管理 (2025-06-01)

- [x] `Constants::Karaoke` を作成した。
- [x] DAM / JOYSOUND の CSS selector を YAML 化した。
- [x] URL、許可リスト、特殊許可楽曲 URL を一元管理した。

### 6. 独自管理画面への移行 (2026-05-10)

- [x] Rails 標準の Controller / View / Policy ベースで管理画面を実装した。
- [x] リソース定義、検索、フィルタ、ソート、詳細、編集、削除、操作を統一した。
- [x] 変更履歴、ダッシュボード、無限スクロール、非同期 index 更新を追加した。

### 7. 管理画面アクションの非同期化 (2026-05-10)

- [x] Active Job + Solid Queue で管理画面アクションを非同期実行できるようにした。
- [x] `Admin::OperationJob` を追加した。
- [x] `Admin::OperationProgress` を DB / cache / memory store で読めるようにした。
- [x] 操作モーダルに進捗表示と polling を追加した。
- [x] `make jobs` と `make up` で worker を起動できるようにした。

## 実装時の注意事項

1. 既存の管理画面操作を壊さないよう、リファクタリングごとに controller test と system test を追加する。
2. 外部サイトアクセスを伴う処理は、ネットワーク失敗、timeout、404、HTML 構造変更を前提にする。
3. 非同期処理は「開始できたこと」と「完了したこと」を別の状態として扱う。
4. 大きな分割は 1 PR で完了させず、Registry、Operation、JavaScript、テストの単位に分ける。
5. 新しい依存関係を追加する前に、Rails 標準機能または既存の service で解決できないか確認する。

## 推奨着手順

1. モデルに残る Ferrum 直書き処理を service/scraper へ移し、HTML fixture ベースのテストを追加する。
2. Solid Queue の失敗時の再実行導線を決める。
3. DB 制約追加は必ず dry-run の重複確認結果を見てから進める。
