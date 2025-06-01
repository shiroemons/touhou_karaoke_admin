# リファクタリング TODO リスト

## 完了済み

### ✅ 1. Webスクレイピング処理の共通化 (2024-06-01)
**問題点**: `Song`, `DamSong`, `JoysoundSong` モデルに散在する Ferrum ブラウザ操作の重複コード
- [x] ブラウザ管理用の共通クラス `BrowserManager` を作成
- [x] リトライ処理の共通化 (`Retryable` concern)
- [x] エラーハンドリングの統一化
- [x] ブラウザオプションの一元管理

**実装内容**:
- `app/services/browser_manager.rb` - Ferrumブラウザ操作を統一管理
- `app/models/concerns/retryable.rb` - リトライ処理を共通化
- `app/services/scrapers/base_scraper.rb` - スクレイパー基底クラス
- `app/services/scrapers/dam_scraper.rb` - DAM専用スクレイパー
- `app/services/scrapers/joysound_scraper.rb` - JOYSOUND専用スクレイパー
- Songモデルから234行削減（545行→311行）

**PR**: [#590](https://github.com/shiroemons/touhou_karaoke_admin/pull/590)

### ✅ 2. 大量データ処理の最適化 (2024-06-01)
**問題点**: 並列処理のロジックが複数箇所で重複
- [x] `ParallelProcessor` concern を作成
- [x] バッチ処理とプログレス表示の共通化
- [x] メモリ効率の改善（`find_in_batches` の統一使用）

**実装内容**:
- `app/models/concerns/parallel_processor.rb` - 並列処理ロジックを統一化
- バッチサイズとプロセス数を設定可能に
- 進捗表示とロギングを標準化
- Songモデルから76行削減

**PR**: [#591](https://github.com/shiroemons/touhou_karaoke_admin/pull/591)

### ✅ 3. 配信機種管理の改善 (2025-06-01)
**問題点**: 配信機種の取得・更新ロジックが分散
- [x] `DeliveryModelManager` service クラスを作成
- [x] 機種名とIDのキャッシュ戦略の改善
- [x] 新規機種の自動作成ロジックの一元化

**実装内容**:
- `app/services/delivery_model_manager.rb` - 配信機種管理を一元化
- スレッドセーフなキャッシング機構（TTL: 60分）
- 重複作成を防ぐユニーク制約の追加
- `BaseScraper` を更新してDeliveryModelManagerを使用
- 並列処理時の競合状態を解決

**PR**: [#592](https://github.com/shiroemons/touhou_karaoke_admin/issues/592)

### ✅ 4. Songモデルの責務分割 (2025-06-01)
**問題点**: ~~Songモデルが肥大化（545行）~~ → 165行に削減済み（234行 + 76行 + 70行削減）
- [x] スクレイピング処理を Service クラスに移動
  - `Scrapers::DamScraper`
  - `Scrapers::JoysoundScraper`
- [x] 並列処理ロジックを concern に移動
  - `ParallelProcessor`
- [x] Algolia検索関連を concern に切り出し
  - `AlgoliaSearchable`
- [x] カテゴリ関連メソッドを concern に切り出し
  - `Categorizable`

**PR**: [#595](https://github.com/shiroemons/touhou_karaoke_admin/pull/595)

### ✅ 5. 定数の整理と管理 (2025-06-01)
**問題点**: URL、セレクタ、定数が各所に散在
- [x] `Constants::Karaoke` モジュールを作成
- [x] CSSセレクタを YAML ファイルに外出し
- [x] 許可リスト（ALLOWLIST）の管理方法改善

**実装内容**:
- `lib/constants/karaoke.rb` - カラオケ関連の定数を一元管理
  - DAMとJOYSOUND用のURL定数を整理
  - 許可された作曲者リストと特別許可楽曲URLを管理
- `config/selectors/dam.yml` - DAMのCSSセレクタ定義
- `config/selectors/joysound.yml` - JOYSOUNDのCSSセレクタ定義
- 全モデルとスクレイパーを新しい定数構造に移行

**PR**: [#596](https://github.com/shiroemons/touhou_karaoke_admin/pull/596)

## 優先度: 高

## 優先度: 中

### 6. Avo アクションの共通化
**問題点**: 似たような fetch 処理が複数存在
- [ ] 基底クラス `BaseFetchAction` を作成
- [ ] エラーハンドリングの統一
- [ ] 実行結果の通知方法の改善

## 優先度: 低

### 7. テストの追加と改善
**問題点**: スクレイピング処理のテストが不足
- [ ] VCR を使用したスクレイピングテストの追加
- [ ] Service クラスの単体テスト作成
- [ ] モデルの validation テストの充実

### 8. ログ出力の改善
**問題点**: logger.debug の使用が統一されていない
- [ ] 構造化ログの導入
- [ ] ログレベルの適切な使い分け
- [ ] 進捗表示用の専用ロガー作成

### 9. 非同期処理の検討
**問題点**: 大量のWeb APIアクセスでパフォーマンスボトルネック
- [ ] Sidekiq や ActiveJob での非同期化
- [ ] バックグラウンドでの定期実行
- [ ] 処理状況の可視化

### 10. データベースクエリの最適化
**問題点**: N+1 問題の可能性がある箇所
- [ ] includes の適切な使用確認
- [ ] 複雑なクエリの最適化
- [ ] インデックスの見直し

## 実装時の注意事項

1. **段階的なリファクタリング**: 一度に大きな変更を行わず、小さな改善を積み重ねる
2. **後方互換性の維持**: 既存の処理に影響を与えないよう注意
3. **パフォーマンス測定**: リファクタリング前後でパフォーマンスを比較
4. **ドキュメント化**: 新しいクラスやメソッドには適切なコメントを追加

## 期待される効果

- コードの重複削減により、保守性が向上
- バグ修正が一箇所で済むようになる
- 新機能追加時の開発速度向上
- テストカバレッジの向上による品質改善
- パフォーマンスの改善