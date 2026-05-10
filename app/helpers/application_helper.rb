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
      fragments << link_to(url, url, target: "_blank", rel: "noopener")
      last_index = match.end(0)
    end

    fragments << text[last_index..]

    simple_format(safe_join(fragments), {}, sanitize: false)
  end
end
