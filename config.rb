require "contentful"
require "rich_text_renderer"
require "redcarpet"
require "redcarpet/render_strip"

# Initialize Contentful Delivery API client.
client = Contentful::Client.new(
  access_token: ENV["CONTENTFUL_DELIVERY_API_KEY"],
  space:        ENV["CONTENTFUL_SPACE_ID"]
)

helpers do

  # Custom helper for converting Rich Text to HTML
  def rich_text_to_html(value)

    renderer = RichTextRenderer::Renderer.new
    renderer.render(value)

  end

  # Custom helper for convert Markdown to HTML
  def markdown_to_html(value)

    renderer = Redcarpet::Markdown.new(
    	Redcarpet::Render::HTML,
    	autolink:     false,
    	tables:       true,
    	escape_html:  false
    )

    renderer.render(value)

  end

end

# Query entries that match the content type 'Page'.
# Parameter `include` is set to 0, since we don't need related entries.
# Parameter `limit` value set as 10 for development, 1000 for build.
pages = client.entries(
  content_type: "page",
  include:      0,
  select:       "fields.slug",
  limit:        build? ? 1000 : 10
)

# Map the 'Slug' field values of 'Page' entries into a flat array.
page_slugs = pages.map do |page|
  page.fields[:slug]
end

# Query 'Pages' entry and set corresponding proxy.
page_slugs.each do |page_slug|

  # Query 'Page' entry by 'Slug' field value.
  page = client.entries(
    content_type:   "page",
    include:        2,
    "fields.slug":  page_slug
  ).first

  # Set proxy for 'Slug' field value and pass 'Page' entry's data to template.
  proxy "/pages/#{page_slug}/index.html", "/pages/page.html", locals: {
    page: page
  }

end

# Ignore template on build
ignore "/pages/page.html"

# Activate and configure extensions.
# https://middlemanapp.com/advanced/configuration/#configuring-extensions

activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end