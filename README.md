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