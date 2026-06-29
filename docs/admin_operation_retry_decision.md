# 管理画面 失敗ジョブ再実行導線の判断

最終更新: 2026-06-29

## 結論

失敗ジョブの汎用「再実行」ボタンは現時点では追加しない。失敗した操作は、管理画面の操作フォームまたは運用フロー画面から同じ操作を再実行する運用にする。

## 理由

- `Admin::OperationProgress` は進捗表示用の状態を保存しているが、再実行に必要な `resource_key`、`operation_key`、`record_id`、`params` 一式を再利用可能な履歴として保持していない。
- operation には外部サイト取得、DB更新、削除、TSV出力、ファイル入力などが混在しており、全操作を同じUIから安全に再実行できるとは限らない。
- `repeat_while_created` が必要な運用フロー内の再試行は `WorkflowRunJob` 側で `max_attempts` に従って制御済み。
- 失敗時の詳細は進捗パネルとログで確認でき、同じ操作を再度開始する既存導線は残っている。

## 将来追加する場合の条件

1. 再実行可能な operation を `retry_strategy: :manual` などで明示する。
2. 再実行に必要な入力を、ファイル upload や即時 download を除いて永続化する。
3. 削除や外部取得など副作用の強い操作では、dry-run または確認画面を必須にする。
4. 再実行時は新しい `operation_progress_id` を発行し、元の失敗 progress とは別履歴として記録する。
5. workflow step の再実行は、単独 operation ではなく workflow の文脈で扱う。

## 現在の代替導線

- 単独 operation: 対象リソースの操作フォームから再実行する。
- 運用フロー: workflow 画面からフローを再実行する。件数が不自然な場合の再実行方針は workflow ガイド内に表示済み。
- 原因調査: `Admin::OperationJob` / `Admin::WorkflowRunJob` のログに `resource`、`operation`、`progress_id`、`actor`、入力概要が出力される。
