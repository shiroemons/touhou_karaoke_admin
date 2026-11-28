# frozen_string_literal: true

module Admin
  # 配信期限を「期限切れ／残り30日以内／残り31〜90日／残り91日以上」に区切る定義。
  # 一覧の絞り込み・ワークフロー画面の内訳・ミュージックポストの優先取得で同じ区切りを使い、件数がずれないようにする。
  module DeliveryDeadlineWindows
    SOON_DAYS = 30
    LATER_DAYS = 90
    ACTIVE_LABEL = '期限内すべて'
    # 配信期限は日本の日付なので、アプリのタイムゾーン（UTC）ではなく日本時間の「今日」で判定する
    TIME_ZONE = 'Asia/Tokyo'

    Window = Data.define(:key, :label, :range_builder) do
      def range(today)
        range_builder.call(today)
      end
    end

    Summary = Data.define(:earliest, :latest, :active_count, :counts, :monthly_counts)

    WINDOWS = [
      Window.new(key: 'expired', label: '期限切れ', range_builder: ->(today) { ...today }),
      Window.new(key: 'within_30_days', label: "残り#{SOON_DAYS}日以内", range_builder: ->(today) { today..(today + SOON_DAYS) }),
      Window.new(key: 'days_31_to_90', label: "残り#{SOON_DAYS + 1}〜#{LATER_DAYS}日", range_builder: ->(today) { (today + SOON_DAYS + 1)..(today + LATER_DAYS) }),
      Window.new(key: 'over_90_days', label: "残り#{LATER_DAYS + 1}日以上", range_builder: ->(today) { (today + LATER_DAYS + 1).. })
    ].freeze

    module_function

    def fetch(key)
      WINDOWS.find { |window| window.key == key.to_s }
    end

    # 日本時間の今日。期限切れの判定・残り日数・絞り込みはすべてこの日付を使う
    def current_date
      Time.find_zone!(TIME_ZONE).today
    end

    # 今日から「残り30日以内」の終わりまで。期限が近いものを優先して取り直す処理で使う。
    def soon_until(today = current_date)
      today + SOON_DAYS
    end

    # 期限内（今日以降）の最短・最長日、区切りごとの件数、月別の件数をまとめる。
    # 期限日ごとの件数を1回のクエリで取り、区切りや月への振り分けはRuby側で行う。
    def summarize(scope, column, today: current_date)
      counts_by_date = scope.where.not(column => nil).group(column).count
      active_counts = counts_by_date.select { |date, _count| date >= today }

      Summary.new(
        earliest: active_counts.keys.min,
        latest: active_counts.keys.max,
        active_count: active_counts.values.sum,
        counts: WINDOWS.to_h { |window| [window.key, count_within(counts_by_date, window.range(today))] },
        monthly_counts: monthly_counts(active_counts)
      )
    end

    def count_within(counts_by_date, range)
      counts_by_date.sum { |date, count| range.cover?(date) ? count : 0 }
    end

    # 最初の月から最後の月まで、件数0の月も含めて [月初日, 件数] を並べる。
    def monthly_counts(counts_by_date)
      return [] if counts_by_date.empty?

      totals = counts_by_date.each_with_object(Hash.new(0)) { |(date, count), sums| sums[date.beginning_of_month] += count }
      first_month, last_month = totals.keys.minmax

      Enumerator.produce(first_month, &:next_month).take_while { |month| month <= last_month }.map { |month| [month, totals[month]] }
    end

    def remaining_days_label(deadline, today: current_date)
      return if deadline.blank?

      days = (deadline - today).to_i
      return "期限切れ（#{-days}日経過）" if days.negative?
      return '今日まで' if days.zero?

      "あと#{days}日"
    end
  end
end
