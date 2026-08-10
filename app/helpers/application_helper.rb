module ApplicationHelper
  URL_PATTERN = %r{https?://[^\s<）)]+}

  def linked_operation_description(description)
    text = description.to_s
    fragments = []
    last_index = 0

    text.to_enum(:scan, URL_PATTERN).each do
      match = Regexp.last_match
      url = match[0]

      fragments << text[last_index...match.begin(0)]
      fragments << link_to(
        operation_url_link_label(url),
        url,
        target: "_blank",
        rel: "noopener",
        title: url,
        aria: { label: "#{url}（新しいタブで開く）" }
      )
      last_index = match.end(0)
    end

    fragments << text[last_index..]

    simple_format(safe_join(fragments), {}, sanitize: false)
  end

  def operation_url_link_label(url)
    compact_url = url.to_s.sub(%r{\Ahttps?://}, '').sub(/[?#].*\z/, '…')
    compact_url.truncate(56, omission: '…')
  end
end
