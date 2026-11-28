require 'test_helper'

module Admin
  class DeliveryDeadlineWindowsTest < ActiveSupport::TestCase
    TODAY = Date.new(2026, 11, 28)

    def window_key_for(date)
      DeliveryDeadlineWindows::WINDOWS.find { |window| window.range(TODAY).cover?(date) }&.key
    end

    def create_music_post(deadline, suffix)
      JoysoundMusicPost.create!(
        title: "期限テスト#{suffix}",
        artist: 'テストアーティスト',
        producer: 'producer',
        delivery_deadline_on: deadline,
        url: "https://example.com/music-post/deadline-#{suffix}"
      )
    end

    test '各日付はちょうど1つの区切りに入り、境界は残り日数で判定される' do
      {
        TODAY - 1 => 'expired',
        TODAY => 'within_30_days',
        TODAY + 30 => 'within_30_days',
        TODAY + 31 => 'days_31_to_90',
        TODAY + 90 => 'days_31_to_90',
        TODAY + 91 => 'over_90_days',
        TODAY + 400 => 'over_90_days'
      }.each do |date, expected|
        matched = DeliveryDeadlineWindows::WINDOWS.count { |window| window.range(TODAY).cover?(date) }

        assert_equal 1, matched, "#{date} が複数またはどの区切りにも入っていない"
        assert_equal expected, window_key_for(date), "#{date} の区切り"
      end
    end

    test '今日は日本時間で判定する（UTCではまだ前日の日本時間0時台）' do
      travel_to Time.utc(2026, 11, 28, 15, 30) do
        assert_equal Date.new(2026, 11, 28), Date.current
        assert_equal Date.new(2026, 11, 29), DeliveryDeadlineWindows.current_date
        assert_equal '期限切れ（1日経過）', DeliveryDeadlineWindows.remaining_days_label(Date.new(2026, 11, 28))
        assert_equal Date.new(2026, 12, 29), DeliveryDeadlineWindows.soon_until
      end
    end

    test '区切りの名前は残り日数で書く' do
      assert_equal %w[期限切れ 残り30日以内 残り31〜90日 残り91日以上], DeliveryDeadlineWindows::WINDOWS.map(&:label)
    end

    test '残り日数の表示' do
      assert_equal '期限切れ（3日経過）', DeliveryDeadlineWindows.remaining_days_label(TODAY - 3, today: TODAY)
      assert_equal '今日まで', DeliveryDeadlineWindows.remaining_days_label(TODAY, today: TODAY)
      assert_equal 'あと1日', DeliveryDeadlineWindows.remaining_days_label(TODAY + 1, today: TODAY)
      assert_equal 'あと117日', DeliveryDeadlineWindows.remaining_days_label(TODAY + 117, today: TODAY)
      assert_nil DeliveryDeadlineWindows.remaining_days_label(nil, today: TODAY)
    end

    test '期限内の範囲と区切りごとの件数を集計し、件数の合計は全件と一致する' do
      [TODAY - 5, TODAY, TODAY + 30, TODAY + 31, TODAY + 91, TODAY + 200].each_with_index do |deadline, index|
        create_music_post(deadline, index)
      end

      summary = DeliveryDeadlineWindows.summarize(JoysoundMusicPost, :delivery_deadline_on, today: TODAY)

      assert_equal TODAY, summary.earliest
      assert_equal TODAY + 200, summary.latest
      assert_equal 5, summary.active_count
      assert_equal({ 'expired' => 1, 'within_30_days' => 2, 'days_31_to_90' => 1, 'over_90_days' => 2 }, summary.counts)
      assert_equal JoysoundMusicPost.count, summary.counts.values.sum
    end

    test '月別の件数は期限内だけを数え、間の0件の月も並べる' do
      [TODAY - 5, TODAY, TODAY + 3, Date.new(2027, 2, 10), Date.new(2027, 2, 20)].each_with_index do |deadline, index|
        create_music_post(deadline, "month-#{index}")
      end

      summary = DeliveryDeadlineWindows.summarize(JoysoundMusicPost, :delivery_deadline_on, today: TODAY)

      assert_equal(
        [[Date.new(2026, 11, 1), 1], [Date.new(2026, 12, 1), 1], [Date.new(2027, 1, 1), 0], [Date.new(2027, 2, 1), 2]],
        summary.monthly_counts
      )
    end

    test '期限内のデータがなければ範囲はnilになる' do
      create_music_post(TODAY - 1, 'expired-only')

      summary = DeliveryDeadlineWindows.summarize(JoysoundMusicPost, :delivery_deadline_on, today: TODAY)

      assert_nil summary.earliest
      assert_nil summary.latest
      assert_equal 0, summary.active_count
      assert_empty summary.monthly_counts
    end
  end
end
