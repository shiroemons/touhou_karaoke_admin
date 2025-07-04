# frozen_string_literal: true

# 中断可能・再開可能な処理を実現するサービスクラス
#
# 概要:
#   大量のデータ処理中に中断した場合でも、途中から再開できる機能を提供
#   処理状態をRedisまたはファイルに保存し、進捗を管理
#
# 使用例:
#   processor = ResumableProcessor.new("joysound_fetch_2024_01_04")
#
#   # 新規開始または再開
#   processor.process(JoysoundMusicPost.all) do |record, index|
#     # 処理内容
#     scraper.scrape_music_post_page(record)
#   end
#
#   # 進捗確認
#   puts processor.progress
#   # => { total: 1000, processed: 500, percentage: 50.0 }
class ResumableProcessor
  attr_reader :process_id, :state_file

  def initialize(process_id, state_dir: Rails.root.join('tmp/processing_states'))
    @process_id = process_id
    @state_dir = state_dir
    @state_file = File.join(@state_dir, "#{process_id}.json")

    FileUtils.mkdir_p(@state_dir)
    load_state
  end

  # 処理を実行（新規または再開）
  def process(collection, batch_size: 100)
    @state[:total] ||= collection.count
    @state[:status] = 'processing'
    save_state

    begin
      # 処理済みのIDをスキップ
      remaining = if @state[:processed_ids].any?
                    collection.where.not(id: @state[:processed_ids])
                  else
                    collection
                  end

      remaining.find_in_batches(batch_size: batch_size).with_index do |batch, _batch_index|
        batch.each_with_index do |record, index|
          global_index = @state[:processed_count] + index

          # 処理実行
          begin
            yield(record, global_index)
            mark_as_processed(record.id)
          rescue StandardError => e
            add_error(record.id, e.message)
            Rails.logger.error("Error processing record #{record.id}: #{e.message}")
          end

          # 定期的に状態を保存
          save_state if ((global_index + 1) % 10).zero?
        end

        @state[:processed_count] += batch.size
        save_state
      end

      @state[:status] = 'completed'
      @state[:completed_at] = Time.current
      save_state
    rescue Interrupt
      @state[:status] = 'interrupted'
      save_state
      Rails.logger.info("Processing interrupted. Progress saved: #{progress}")
      raise
    end
  end

  # 進捗を取得
  def progress
    return { total: 0, processed: 0, percentage: 0.0 } if @state[:total].to_i.zero?

    {
      total: @state[:total],
      processed: @state[:processed_count],
      percentage: (@state[:processed_count].to_f / @state[:total] * 100).round(2),
      status: @state[:status],
      errors: @state[:errors].count
    }
  end

  # 処理をリセット
  def reset!
    @state = initial_state
    save_state
  end

  # 処理を再開可能か確認
  def resumable?
    %w[interrupted processing].include?(@state[:status])
  end

  # エラーレポートを取得
  def error_report
    {
      total_errors: @state[:errors].count,
      error_ids: @state[:errors].keys,
      sample_errors: @state[:errors].first(10).to_h
    }
  end

  private

  def initial_state
    {
      process_id: @process_id,
      total: 0,
      processed_count: 0,
      processed_ids: [],
      errors: {},
      status: 'pending',
      started_at: Time.current,
      updated_at: Time.current
    }
  end

  def load_state
    if File.exist?(@state_file)
      @state = JSON.parse(File.read(@state_file)).deep_symbolize_keys
      @state[:started_at] = Time.zone.parse(@state[:started_at]) if @state[:started_at]
      @state[:updated_at] = Time.zone.parse(@state[:updated_at]) if @state[:updated_at]
      @state[:completed_at] = Time.zone.parse(@state[:completed_at]) if @state[:completed_at]
    else
      @state = initial_state
    end
  end

  def save_state
    @state[:updated_at] = Time.current
    File.write(@state_file, JSON.pretty_generate(@state))
  end

  def mark_as_processed(record_id)
    @state[:processed_ids] << record_id
  end

  def add_error(record_id, message)
    @state[:errors][record_id] = {
      message: message,
      timestamp: Time.current
    }
  end
end
