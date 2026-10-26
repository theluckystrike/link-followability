# link_followability

A small Crystal shard that reads links the way search engines do: every `rel`
token on every `<a>`, plus the page-level `<meta name="robots">` and the
`X-Robots-Tag` response header.

- `nofollow`, `ugc` and `sponsored` are reported as not-followed hints; an
  anchor can carry more than one of them.
- `noopener` and `noreferrer` are browser-security tokens and do not change
  whether a link is followed.
- `none` in a robots directive means `noindex, nofollow`.
- A crawler-scoped header such as `X-Robots-Tag: googlebot: noindex` applies
  only to that crawler.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  link_followability:
    github: theluckystrike/link-followability
```

Then run `shards install`.

## Usage

```crystal
require "link_followability"

html = %(<meta name="robots" content="index, follow">
<a href="https://example.com/a" rel="noopener noreferrer">A</a>
<a href="https://example.com/b" rel="ugc nofollow">B</a>)

page = LinkFollowability.merge(
  LinkFollowability.parse_directives(LinkFollowability.meta_robots(html)),
  LinkFollowability.parse_x_robots_tag(nil),
)

LinkFollowability.anchors(html).each do |a|
  puts "#{a.href} followed=#{LinkFollowability.followed?(a, page)} hints=#{a.hints}"
end
# https://example.com/a followed=true hints=[]
# https://example.com/b followed=false hints=["ugc", "nofollow"]
```

## API

| Method | Returns |
|---|---|
| `LinkFollowability.anchors(html)` | Every `<a>` with an href, in order, as `Anchor(href, rel, index)`; comments and `<script>` bodies are ignored |
| `Anchor#hints` / `Anchor#rel_followed?` | The nofollow/ugc/sponsored tokens on the anchor; true when there are none |
| `LinkFollowability.rel_tokens(rel)` | Lower-cased, de-duplicated tokens split on ASCII whitespace |
| `LinkFollowability.meta_robots(html)` | Content of the first robots meta tag, or `nil` |
| `LinkFollowability.parse_directives(value)` | `PageDirectives(noindex, nofollow)` |
| `LinkFollowability.parse_x_robots_tag(value, user_agent = "googlebot")` | Directives that apply to that crawler |
| `LinkFollowability.merge(*sets)` | Any noindex / nofollow wins |
| `LinkFollowability.followed?(anchor, page)` | Anchor rel-followed and the page is not nofollow |

The anchor scanner tokenizes start tags; it is not a full HTML5 parser, so
feed it the served HTML, not a DOM produced by client-side JavaScript.

## Related

For a no-install version, the
[paste-your-HTML rel token checker](https://handsofflinks.com/dofollow-nofollow-checker/)
on handsofflinks.com prints the same per-anchor rel tokens in the browser.

## Development

```sh
crystal spec
```

## License

MIT
