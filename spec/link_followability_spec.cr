require "spec"
require "../src/link_followability"

describe LinkFollowability do
  it "splits rel tokens on any ASCII whitespace and lower-cases them" do
    LinkFollowability.rel_tokens("Nofollow\tUGC  noopener").should eq ["nofollow", "ugc", "noopener"]
    LinkFollowability.rel_tokens(nil).should eq [] of String
    LinkFollowability.rel_tokens("   ").should eq [] of String
  end

  it "treats noopener and noreferrer as followed" do
    a = LinkFollowability.anchors(%(<a rel="noopener noreferrer" href="https://example.com/">x</a>)).first
    a.rel_followed?.should be_true
    a.hints.should eq [] of String
  end

  it "reports every not-followed hint on one anchor" do
    a = LinkFollowability.anchors(%(<a href="https://example.com/" rel="ugc nofollow noopener">x</a>)).first
    a.rel_followed?.should be_false
    a.hints.should eq ["ugc", "nofollow"]
  end

  it "reads unquoted and single-quoted attributes" do
    list = LinkFollowability.anchors(%(<a href=https://a.example/ rel=nofollow>a</a><a href='https://b.example/' rel='sponsored'>b</a>))
    list.map(&.href).should eq ["https://a.example/", "https://b.example/"]
    list.map(&.hints).should eq [["nofollow"], ["sponsored"]]
  end

  it "skips anchors without href and anchors inside comments or scripts" do
    html = %(<a name="top"></a><!-- <a href="https://hidden.example/">h</a> --><script>var s = '<a href="https://js.example/">';</script><a href="/ok">ok</a>)
    LinkFollowability.anchors(html).map(&.href).should eq ["/ok"]
  end

  it "parses meta robots, including none" do
    html = %(<head><meta content="noindex, nofollow" name="ROBOTS"></head>)
    LinkFollowability.meta_robots(html).should eq "noindex, nofollow"
    d = LinkFollowability.parse_directives("none")
    d.noindex.should be_true
    d.nofollow.should be_true
    LinkFollowability.parse_directives("index, follow").should eq LinkFollowability::PageDirectives.new(false, false)
  end

  it "applies crawler-scoped X-Robots-Tag only to that crawler" do
    LinkFollowability.parse_x_robots_tag("googlebot: noindex").noindex.should be_true
    LinkFollowability.parse_x_robots_tag("bingbot: noindex").noindex.should be_false
    LinkFollowability.parse_x_robots_tag("bingbot: noindex", "bingbot").noindex.should be_true
    LinkFollowability.parse_x_robots_tag("noindex, nofollow").nofollow.should be_true
  end

  it "does not mistake unavailable_after for a crawler scope" do
    d = LinkFollowability.parse_x_robots_tag("unavailable_after: 25 Jun 2010 15:00:00 PST")
    d.noindex.should be_false
  end

  it "lets page-level nofollow override a rel-free anchor" do
    a = LinkFollowability.anchors(%(<a href="https://example.com/">x</a>)).first
    page = LinkFollowability.merge(LinkFollowability.parse_directives(nil), LinkFollowability.parse_x_robots_tag("nofollow"))
    LinkFollowability.followed?(a, page).should be_false
    LinkFollowability.followed?(a, LinkFollowability.parse_directives("all")).should be_true
  end
end
