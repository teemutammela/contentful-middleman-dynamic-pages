# Dynamic Pages with Contentful and Middleman

Guide for creating dynamic pages with the [Contentful](https://www.contentful.com/) content management platform and the [Middleman](https://middlemanapp.com/) static site generator. Prior methods of combining Contentful and Middleman, such as the [contentful_middleman](https://github.com/contentful/contentful_middleman) gem, involved exporting Contentful entries as a JSON file. The dynamic page approach, however, streamlines the development by querying content in real time via the Contentful Delivery API without the need for exporting files.

In addition, this tutorial describes how to deploy the application to [Netlify](https://www.netlify.com/) and how to setup a Contentful webhook to rebuild the site whenever entries are published. This tutorial is written with Unix-like operating systems such as macOS or Linux in mind.

__NOTE!__ The source code found in this repository is the __end result__ of this tutorial. Both cloning the repository _and_ carrying out the tutorial is not necessary. Furthermore, this example is boilerplate code and not by any means a comprehensive guide to Contentful and Middleman.

## Contentful

[Contentful](https://www.contentful.com/) provides a content infrastructure for digital teams to power content in websites, apps, and devices. Unlike a CMS, Contentful was built to integrate with the modern software stack. It offers a central hub for structured content, powerful management and delivery APIs, and a customizable web app that enable developers and content creators to ship digital products faster.

Contentful is registered trademark of Contentful GmbH.

## Author

__Teemu Tammela__

* [teemu.tammela@auralcandy.net](mailto:teemu.tammela@auralcandy.net)
* [www.auralcandy.net](https://www.auralcandy.net/)
* [github.com/teemutammela](https://github.com/teemutammela)
* [www.linkedin.com/in/teemutammela](https://www.linkedin.com/in/teemutammela/)
* [t.me/teemutammela](http://t.me/teemutammela)

## Disclaimer

This source code is distributed under [Unlicense](https://unlicense.org/) and comes with __absolutely no warranty__. The author assumes no responsibility for data loss or any other unintended side-effects.

## Table of Contents

* [Requirements](#requirements)
* [Import Example Content](#import-example-content)
* [Ruby & RVM Setup](#ruby-rvm-setup)
* [Middleman Setup](#middleman-setup)
* [Contentful Setup](#contentful-gems-setup)
* [Dynamic Pages Setup](#dynamic-pages-setup)
* [Deploy to Netlify](#deploy-to-netlify)
* [Webhook Setup](#webhook-setup)

## Requirements

* [Contentful CLI](https://github.com/contentful/contentful-cli)
* [Ruby](https://www.ruby-lang.org/en/) (3.1.2)
* [RVM](https://rvm.io/)
* [Bundler](https://bundler.io/)
* [Git](https://git-scm.com/) (optional)
* [GitHub](https://github.com/), [GitLab](https://about.gitlab.com/) or [Bitbucket](https://bitbucket.org/) account (optional)
* [Netlify](https://www.netlify.com/) account (optional)

## Import Example Content

__1)__ Login to Contentful CLI and select the target space.

```shell
$ contentful login
$ contentful space use
```

__2)__ Import content model `Page` and example entries to target space.

```shell
$ contentful space import --content-file setup/example_content.json
```

## Ruby & RVM Setup

__1)__ It's highly recommended to have [RVM](https://rvm.io/) (Ruby Version Manager) installed. RVM makes installing and managing various Ruby versions a breeze. Once you have RVM installed, install Ruby `3.1.2` and set it as the default version in your project directory.

```shell
$ rvm install 3.1.2
$ rvm use 3.1.2 --default
```

__2)__ Make sure you have the Ruby version `3.1.2` installed and set as the active Ruby version.

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

__2)__ Create a project directory and set up the default Middleman installation.

```shell
$ mkdir my_project_dir
$ cd my_project_dir/
$ middleman init
```

__NOTE!__ If you encounter an error while `middleman init` or `middleman server`, you may have to create `Gemfile` in advance and/or define strict version number for the `haml` gem.

```ruby
gem 'haml', '~> 5.0'
```

__3)__ Modify the `Gemfile` by adding the Ruby version as well as the `contentful` and `rich_text_renderer` gems. Using exact gem version numbers is not absolutely necessary, simply a precaution to ensure this tutorial works as intended.

```ruby
# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.1.2'

gem 'contentful', '2.16.3'
gem 'middleman', '4.4.2'
gem 'middleman-autoprefixer', '3.0.0'
gem 'redcarpet', '3.5.1'
gem 'rich_text_renderer', '0.3.0'
gem 'rubocop', '1.36.0'
gem 'tzinfo-data', platforms: %i[mswin mingw jruby x64_mingw]
gem 'wdm', '~> 0.1', platforms: %i[mswin mingw x64_mingw]
```

__4)__ Finish the installation by executing Bundler once again.

```shell
$ bundle install
```

__5)__ Start the Middleman server. You should now see Middleman's default page at [http://localhost:4567](http://localhost:4567). By default Middleman runs at port `4567`. Change the default parameter using the `-p` parameter (e.g. `middleman server -p 9292`).

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

__2)__ Create a copy of the `.env.example` file and insert the Delivery API key and Space ID. See Contentful's [authentication documentation](https://www.contentful.com/developers/docs/references/authentication/) for instructions how to set up API keys.

```shell
$ cp .env.example .env
```

```
CONTENTFUL_DELIVERY_API_KEY=xyz123
CONTENTFUL_SPACE_ID=xyz123
```

__3)__ Add [Contentful Delivery API client](https://github.com/contentful/contentful.rb), [Rich Text renderer](https://github.com/contentful/rich-text-renderer.rb) and [Redcarpet](https://github.com/vmg/redcarpet) gems to `config.rb`. Redcarpet is a library for converting Markdown into HTML.

```ruby
require 'contentful'
require 'rich_text_renderer'
require 'redcarpet'
require 'redcarpet/render_strip'
```

__4)__ Add the Contentful Delivery API client to `config.rb`. Delivery API key and Space ID will be loaded from `.env` file.

```ruby
client = Contentful::Client.new(
  access_token: ENV['CONTENTFUL_DELIVERY_API_KEY'],
  space: ENV['CONTENTFUL_SPACE_ID']
)
```

__5)__ Add custom helpers to `config.rb`. These helpers are used for converting Rich Text and Markdown into HTML. This example uses the Rich Text renderer library's default settings. See Rich Text renderer [documentation](https://github.com/contentful/rich-text-renderer.rb) for more details how to create custom renderers for various embedded entry types, or see Redcarpet's [documentation](https://github.com/vmg/redcarpet) for more details about rendering options.

```ruby
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
      autolink: false,
      tables: true,
      escape_html: false
    )

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

__2)__ Insert the following lines of code to `source/pages/page.html.erb`. Notice how we are displaying values from both the `fields` and `sys` properties of the entry. On the last two lines we are using our custom helpers to convert Markdown and Rich Text into HTML.

```erb
---
title: Example Page
---
<h1><%= page.fields[:title] %></h1>
<p><%= page.sys[:updated_at] %></p>
<p><%= markdown_to_html(page.fields[:lead]) %></p>
<p><%= rich_text_to_html(page.fields[:body]) %></p>
```

Mixing raw HTML tags and Ruby syntax doesn’t yield the cleanest template code, so alternatively you can take advantage of [Padrino's tag helpers](https://padrinorb.com/guides/application-helpers/tag-helpers/).

```erb
<%= content_tag :h1, page.fields[:title] %>
<%= content_tag :p, page.sys[:updated_at] %>
<%= content_tag :p, markdown_to_html(page.fields[:lead]) %>
<%= content_tag :p, rich_text_to_html(page.fields[:body]) %>
```

__3)__ Add the following code block to `config.rb`. Query the `Slug` field of every `Page` entry, map the `Slug` field values into a flat array, query the corresponding `Page` entry and set a proxy. See Middleman's [dynamic pages](https://middlemanapp.com/advanced/dynamic-pages/) documentation for more details about proxies.

```ruby
# Query entries that match the content type 'Page'.
# Parameter `include` is set to 0, since we don't need related entries.
# Parameter `limit` value set as 10 for development, 1000 for build.
pages = client.entries(
  content_type: 'page',
  include: 0,
  select: 'fields.slug',
  limit: build? ? 1000 : 10
)

# Map the 'Slug' field values of 'Page' entries into a flat array.
page_slugs = pages.map do |page|
  page.fields[:slug]
end

# Query 'Pages' entry and set corresponding proxy.
page_slugs.each do |page_slug|
  # Query 'Page' entry by 'Slug' field value.
  page = client.entries(
    content_type: 'page',
    include: 2,
    "fields.slug": page_slug
  ).first

  # Set proxy for 'Slug' field value and pass 'Page' entry's data to template.
  proxy "/pages/#{page_slug}/index.html", '/pages/page.html', locals: {
    page:
  }
end
```

__4)__ Add an ignore command to `config.rb`. This will prevent Middleman from trying to build the `Page` template into a HTML page. We're already creating paths for the HTML pages via the proxy.

```ruby
ignore '/pages/page.html'
```

__5)__ Test the proxy at [http://localhost:4567/pages/example-page-1](http://localhost:4567/pages/example-page-1).

__6)__ Test building the site.

```shell
$ middleman build
```

## Deploy to Netlify

__1)__ Create a `.ruby-version` file.

```shell
$ echo "ruby-3.1.2" > .ruby-version
```

__2)__ Push your Middleman app into a [GitHub](https://github.com/), [GitLab](https://about.gitlab.com/) or [Bitbucket](https://bitbucket.org/) repository.

__3)__ Log into [Netflify](https://www.netlify.com/). Sign up to a new account if you don't already have one.

__4)__ Select _Sites_ → _Import an existing project_ on the Netlify dashboard. Select your preferred Git service provider under _Connect to Git provider_ and insert your credentials.

__5)__ Set `middleman build` as the _Build command_ and `build/` as the _Publish directory_. You can configure Netlify to use any branch in your repository as the build source. By default, Netlify launches a new build whenever new commits are pushed to the `main` branch.

__6)__

Go to _Site settings_ → _Build & deploy_ → _Environment_ → _Edit variables_ and set Contentful Delivery API key and Space ID as environmental variables `CONTENTFUL_DELIVERY_API_KEY` and `CONTENTFUL_SPACE_ID`.

## Webhook Setup

__1)__ On Netlify go to _Site settings_ → _Build & deploy_ → _Build hooks_ → _Add build hook_ and create a new build hook. Name the new build hook as _Contentful_. By default, _Branch to build_ is set to `main`. Your new build hook URL should look like this.

`https://api.netlify.com/build_hooks/<WEBHOOK_ID>`

__2)__ On Contentful go to _Settings_ → _Webhooks_ and select _Netlify - Deploy a site_ from the _Webhook templates_ list. Insert the URL to _Netlify build hook URL_ field and select _Create webhook_. By default the webhook is set to trigger whenever entries are published or unpublished. You can change this behavior from _Webhook settings_.