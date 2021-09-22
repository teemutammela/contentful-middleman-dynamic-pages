# Dynamic Pages with Contentful and Middleman

This tutorial describes how to create dynamic pages with the [Contentful](https://www.contentful.com/) content management platform and the [Middleman](https://middlemanapp.com/) static site generator. Prior methods of combining Contentful and Middleman, such as the [contentful_middleman](https://github.com/contentful/contentful_middleman) gem, involved exporting Contentful entries as a JSON file. The dynamic page approach, however, queries content in real time via the Contentful Delivery API without the need for exporting files. In addition, this tutorial also describes how to deploy the application to [Netlify](https://www.netlify.com/). This tutorial is written with Unix-like operating systems such as macOS or Linux in mind.

__NOTE!__ The source code found in this repository is the __end result__ of this tutorial. Both cloning the repository and carrying out the tutorial is not necessary.

This source code is distributed under [Unlicense](https://unlicense.org/) and comes with __absolutely no warranty__. The author assumes no responsibility of data loss or any other unintended side-effects.

## Author

__Teemu Tammela__

* [teemu.tammela@auralcandy.net](mailto:teemu.tammela@auralcandy.net)
* [www.auralcandy.net](https://www.auralcandy.net/)
* [github.com/teemutammela](https://github.com/teemutammela)
* [www.linkedin.com/in/teemutammela](https://www.linkedin.com/in/teemutammela/)
* [t.me/teemutammela](http://t.me/teemutammela)

## Table of Contents

* [Requirements](#requirements)
* [Import Example Content](#import-example-content)
* [Ruby & RVM Setup](#ruby-rvm-setup)
* [Middleman Setup](#middleman-setup)
* [Contentful Setup](#contentful-gems-setup)
* [Dynamic Pages Setup](#dynamic-pages-setup)
* [Deploy to Netlify](#deploy-to-netlify)

## Requirements

* [Contentful CLI](https://github.com/contentful/contentful-cli)
* [Ruby](https://www.ruby-lang.org/en/) (3.0.2)
* [RVM](https://rvm.io/)
* [Bundler](https://bundler.io/)

## Import Example Content

__1)__ Login to Contentful CLI and select the target space.

```shell
$ contentful login
$ contentful space use
```

__2)__ Import content model `Page` to target space.

```shell
$ contentful space import --content-file setup/page_model.json
```

__3)__ Import example entries to target space.

```shell
$ contentful space import --content-file setup/example_pages.json
```

## Ruby & RVM Setup

__1)__ It's highly recommended to have [RVM](https://rvm.io/) (Ruby Version Manager) installed. RVM makes installing and managing various Ruby versions a breeze. Once you have RVM installed, install Ruby `3.0.2` and set it as the default version in your project directory.

```shell
$ rvm install 3.0.2
$ rvm use 3.0.2 --default
```

__2)__ Make sure you have the Ruby version `3.0.2` installed and set as the active Ruby version.

```shell
$ ruby -v
```

__3)__ Install [Bundler](https://bundler.io/) if not already installed.

```shell
$ gem install bundler
```

## Middleman Setup

__1)__ Install the [Middleman](https://middlemanapp.com/) gem.

```shell
$ gem install middleman
```

__2)__ Set up default Middleman installation.

```shell
$ middleman init
```

__3)__ Modify the `Gemfile` by adding the Ruby version and by adding the [Contentful Delivery API client](https://github.com/contentful/contentful.rb) gem `contentful`. Using exact gem version numbers is not absolutely necessary, simply a precaution to ensure this tutorial works as intended.

```
source "https://rubygems.org"

ruby "3.0.2"

gem "middleman", "4.4.0"
gem "middleman-autoprefixer", "3.0.0"
gem "contentful", "2.16.1"
gem "tzinfo-data", platforms: [:mswin, :mingw, :jruby, :x64_mingw]
gem "wdm", "~> 0.1", platforms: [:mswin, :mingw, :x64_mingw]
```

__4)__ Finish the installation by executing Bundler once again.

```shell
$ bundle install
```

__5)__ Start the Middleman server. You should now see Middleman's default page at [http://localhost:4567](http://localhost:4567). By default Middleman runs in port `4567`. Change the default parameter using the `-p` parameter (e.g. `middleman server -p 9292`).

```shell
$ middleman server
```

## Contentful Setup

__1)__ Add `.evn` to `.gitignore` file. It should look like this.

```
.env
.bundle
.cache
.DS_Store
.sass-cache
build/
```

__2)__ Create a copy of the `.env.example` file and add the Delivery API key and Space ID. See Contentful's [authentication documentation](https://www.contentful.com/developers/docs/references/authentication/) for instructions how to set up API keys.


```shell
$ cp .env.example .env
```

```
CONTENTFUL_DELIVERY_API_KEY=xyz123
CONTENTFUL_SPACE_ID=xyz123
```

__3)__ Add Contentful Delivery API client and Rich Text renderer gems to `config.rb`.

```ruby
require "contentful"
require "rich_text_renderer"
```

__4)__ Add the Contentful Delivery API client to `config.rb`. Delivery API key and Space ID will be loaded from `.env` file.

```ruby
client = Contentful::Client.new(
  access_token: ENV["CONTENTFUL_DELIVERY_API_KEY"],
  space:        ENV["CONTENTFUL_SPACE_ID"]
)
```

__5)__ Add a custom helper to `config.rb` for converting Rich Text to HTML. This example uses the library's default settings. See Rich Text renderer [documentation](https://github.com/contentful/rich-text-renderer.rb) for more details how to create custom renderers for various embedded entry types.

```ruby
helpers do

  def rich_text_to_html(value)
    renderer = RichTextRenderer::Renderer.new
    renderer.render(value)
  end

end
```

## Dynamic Pages Setup

__1)__ Create an ERB template file for the `Page` content type.

```shell
$ mkdir source/pages
$ touch source/pages/page.html.erb
```

__2)__ Insert the following lines of code to `source/pages/page.html.erb`. Notice how we are displaying values from both the `fields` and `sys` properties of the entry. On the last line we are using our custom helper to convert Rich Text into HTML.

```html
---
title: Example Page
---
<h1><%= page.fields[:title] %></h1>

<p><%= page.sys[:updated_at] %></p>

<p><%= page.fields[:lead] %></p>

<p><%= rich_text_to_html(page.fields[:body]) %></p>
```

__3)__ Add the following code block to `config.rb`. Query the `Slug` field of every `Page` entry, map the `Slug` field values into a flat array, query the corresponding `Page` entry and set a proxy. See Middleman's documentation for [dynamic pages](https://middlemanapp.com/advanced/dynamic-pages/) for more details about proxies.

```ruby
# Query entries that match the content type 'Page'.
# Parameter 'include' is set to 0, since we don't need related entries.
# Parameter 'limit' value set as 10 for development, 1000 for build.
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

# Query 'Page' entries and set corresponding proxies.
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
```

__4)__ Add an ignore command to `config.rb`. This will prevent Middleman from trying to build the `Page` template into a HTML page. We're already creating paths for the HTML pages via the proxy.

```ruby
ignore "/pages/page.html"
```

__5)__ Test the proxy at [http://localhost:4567/pages/example-page-1](http://localhost:4567/pages/example-page-1).

__6)__ Test building the site.

```shell
$ middleman build
```

## Deploy to Netlify

__1)__ Create a `.ruby-version` file.

```shell
$ echo "ruby-3.0.2" > .ruby-version
```

__SECTION UNDER CONSTRUCTION__