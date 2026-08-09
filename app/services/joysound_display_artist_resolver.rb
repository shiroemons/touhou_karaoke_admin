# frozen_string_literal: true

# JOYSOUNDのアーティストを、アーティスト名とカラオケ種別を軸に解決する。
#
# JOYSOUND側でアーティストIDが変更されることがあるため、アーティストURLを
# 新しいレコードの識別子には使わない。既存URLが404/410で、新URLの存在が確認
# できた場合だけ既存レコードのURLを更新する。
class JoysoundDisplayArtistResolver
  Resolution = Data.define(
    :artist,
    :action,
    :reason,
    :old_url,
    :new_url,
    :old_check,
    :new_check
  )

  NOT_FOUND_STATUS_CODES = [404, 410].freeze

  class Conflict < StandardError; end

  def initialize(url_checker: UrlChecker)
    @url_checker = url_checker
  end

  def resolve(name:, karaoke_type:, url:, existing_song: nil, dry_run: false)
    artist = artist_for(
      name:,
      karaoke_type:,
      existing_song:
    )

    return create_artist(name:, karaoke_type:, url:) if artist.nil?
    return unchanged(artist, url:) if url.blank? || artist.url == url

    update_stale_url(artist, url:, dry_run:)
  end

  private

  attr_reader :url_checker

  def artist_for(name:, karaoke_type:, existing_song:)
    if existing_song
      artist = existing_song.display_artist
      raise Conflict, "既存曲 #{existing_song.id} のアーティストが一致しません" unless artist.name == name && artist.karaoke_type == karaoke_type

      return artist
    end

    candidates = DisplayArtist.where(name:, karaoke_type:).order(:created_at, :id).to_a
    return if candidates.empty?
    return candidates.first if candidates.one?

    raise Conflict, "アーティスト名が重複しているため自動判定できません: #{karaoke_type}/#{name}"
  end

  def create_artist(name:, karaoke_type:, url:)
    artist = DisplayArtist.create_or_find_by!(name:, karaoke_type:) do |record|
      record.url = url.to_s
    end

    if artist.url.present? && artist.url != url
      update_stale_url(artist, url:, dry_run: false)
    else
      log_artist_action(:create, artist, new_url: url)
      Resolution.new(
        artist:,
        action: :created,
        reason: :new_artist,
        old_url: nil,
        new_url: url,
        old_check: nil,
        new_check: nil
      )
    end
  end

  def unchanged(artist, url:)
    Resolution.new(
      artist:,
      action: :unchanged,
      reason: :same_url,
      old_url: artist.url,
      new_url: url,
      old_check: nil,
      new_check: nil
    )
  end

  def update_stale_url(artist, url:, dry_run:)
    old_url = artist.url
    old_check = old_url.present? ? url_checker.check_url(old_url) : { exists: false, status_code: nil, should_retry: false }

    unless NOT_FOUND_STATUS_CODES.include?(old_check[:status_code])
      reason = old_check[:exists].nil? ? :old_url_unverified : :old_url_still_valid
      log_artist_action(:skip, artist, new_url: url, reason:, old_check:)
      return Resolution.new(
        artist:,
        action: :skipped,
        reason:,
        old_url:,
        new_url: url,
        old_check:,
        new_check: nil
      )
    end

    new_check = url_checker.check_url(url)
    unless new_check[:exists]
      reason = new_check[:exists].nil? ? :new_url_unverified : :new_url_invalid
      log_artist_action(:skip, artist, new_url: url, reason:, old_check:, new_check:)
      return Resolution.new(
        artist:,
        action: :skipped,
        reason:,
        old_url:,
        new_url: url,
        old_check:,
        new_check:
      )
    end

    artist.update!(url:) unless dry_run
    action = dry_run ? :would_update_url : :updated_url
    log_artist_action(action, artist, old_url:, new_url: url, old_check:, new_check:)

    Resolution.new(
      artist:,
      action:,
      reason: :old_url_not_found,
      old_url:,
      new_url: url,
      old_check:,
      new_check:
    )
  end

  def log_artist_action(action, artist, **attributes)
    Admin::OperationLogger.log(
      level: action.to_s.start_with?('skip') ? :warn : :info,
      event: :db_update,
      action:,
      resource: :display_artist,
      id: artist.id,
      name: artist.name,
      **attributes
    )
  end
end
