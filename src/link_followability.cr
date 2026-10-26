# Classifies links the way search engines read them: every `rel` token on every
# anchor, plus the page-level `<meta name="robots">` and `X-Robots-Tag` header.
#
# Google treats `nofollow`, `ugc` and `sponsored` as hints that a link should not
# be followed, and more than one of them can sit on the same anchor. `noopener`
# and `noreferrer` are browser-security tokens and do not change followability.
module LinkFollowability
  VERSION = "0.1.0"

  # rel tokens that mark a link as not followed.
  NOT_FOLLOWED_TOKENS = {"nofollow", "ugc", "sponsored"}

  # One anchor found in an HTML document.
  record Anchor, href : String, rel : Array(String), index : Int32 do
    # Tokens from NOT_FOLLOWED_TOKENS present on this anchor, in source order.
    def hints : Array(String)
      rel.select { |t| NOT_FOLLOWED_TOKENS.includes?(t) }
    end

    # True when no nofollow/ugc/sponsored token is present on the anchor itself.
    def rel_followed? : Bool
      hints.empty?
    end
  end

  # Page-level robots directives merged from meta robots and X-Robots-Tag.
  record PageDirectives, noindex : Bool, nofollow : Bool

  # Splits a rel attribute into lower-case tokens. Tokens are separated by ASCII
  # whitespace (HTML spec); duplicates are kept once, order is preserved.
  def self.rel_tokens(rel : String?) : Array(String)
    return [] of String if rel.nil?
    rel.downcase.split(/[ \t\n\f\r]+/, remove_empty: true).uniq
  end

  # Parses a robots directive list such as "noindex, nofollow" or "none".
  # `none` is equivalent to `noindex, nofollow`; `all` sets neither.
  def self.parse_directives(value : String?) : PageDirectives
    return PageDirectives.new(false, false) if value.nil?
    tokens = value.downcase.split(/[\s,]+/, remove_empty: true)
    noindex = tokens.includes?("noindex") || tokens.includes?("none")
    nofollow = tokens.includes?("nofollow") || tokens.includes?("none")
    PageDirectives.new(noindex, nofollow)
  end

  # Parses one X-Robots-Tag header value. A value may be scoped to a crawler
  # ("googlebot: noindex"); scoped values only apply when `user_agent` matches
  # (case-insensitive). Unscoped values apply to every crawler. Directives that
  # carry their own value after a colon (e.g. "unavailable_after: ...") are not
  # mistaken for a crawler scope.
  def self.parse_x_robots_tag(value : String?, user_agent : String = "googlebot") : PageDirectives
    return PageDirectives.new(false, false) if value.nil?
    if m = value.match(/\A\s*([A-Za-z0-9_\-]+)\s*:\s*(.*)\z/m)
      scope = m[1].downcase
      unless {"unavailable_after", "max-snippet", "max-image-preview", "max-video-preview"}.includes?(scope)
        return PageDirectives.new(false, false) unless scope == user_agent.downcase
        return parse_directives(m[2])
      end
    end
    parse_directives(value)
  end

  # Merges several directive sets; any noindex/nofollow wins.
  def self.merge(*sets : PageDirectives) : PageDirectives
    PageDirectives.new(sets.any?(&.noindex), sets.any?(&.nofollow))
  end

  # Extracts every `<a>` start tag with an href, in document order. Handles
  # double-quoted, single-quoted and unquoted attribute values. Anchors without
  # an href are skipped. This is a tokenizer for start tags, not a full HTML
  # parser: comments and script bodies are removed first so that markup inside
  # them is not counted.
  def self.anchors(html : String) : Array(Anchor)
    cleaned = html.gsub(/<!--.*?-->/m, "").gsub(/<script\b.*?<\/script>/mi, "")
    result = [] of Anchor
    cleaned.scan(/<a\b([^>]*)>/i) do |m|
      attrs = parse_attributes(m[1])
      href = attrs["href"]?
      next if href.nil?
      result << Anchor.new(href, rel_tokens(attrs["rel"]?), result.size)
    end
    result
  end

  # Returns the content of the first `<meta name="robots">` tag, or nil.
  def self.meta_robots(html : String) : String?
    html.scan(/<meta\b([^>]*)>/i) do |m|
      attrs = parse_attributes(m[1])
      if (name = attrs["name"]?) && name.downcase == "robots"
        return attrs["content"]?
      end
    end
    nil
  end

  # Whether a given anchor is followed once page-level directives are applied.
  def self.followed?(anchor : Anchor, page : PageDirectives) : Bool
    anchor.rel_followed? && !page.nofollow
  end

  private def self.parse_attributes(s : String) : Hash(String, String)
    attrs = {} of String => String
    s.scan(/([^\s=\/>"']+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/) do |m|
      key = m[1].downcase
      next if attrs.has_key?(key) # first occurrence wins, as in browsers
      attrs[key] = m[2]? || m[3]? || m[4]? || ""
    end
    attrs
  end
end
