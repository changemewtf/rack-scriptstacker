# Rack::ScriptStacker

Painless static file handling for Rack apps.

- Automatically configures `Rack::Static` by default.
- Glob and inject JavaScript/CSS files into served HTML.
  - Inserts CSS before `</head>` and JS before `</body>` by default.
  - Change the inject mode to use placeholder slots instead.

# Usage

```html
<!-- index.html //-->

<!doctype html>
<html lang="en">
    <head>
    </head>
    <body>
    </body>
</html>
```

and

```ruby
# config.ru

require 'rack/scriptstacker'

class App
  def call env
    [
      200,
      {'Content-Type' => 'text/html'},
      [File.read('index.html')]
    ]
  end
end

use Rack::ScriptStacker do
  css 'static/css'
  javascript 'static/javascript'
end

run app
```

Results in...

```html
<!doctype html>
<html lang="en">
    <head>
      <link rel="stylesheet" type="text/css" href="/static/css/main.css" />
    </head>
    <body>
      <script type="text/javascript" src="/static/javascript/main.js"></script>
      <script type="text/javascript" src="/static/javascript/util.js"></script>
    </body>
</html>
```

## Configure static serving yourself

```ruby
use Rack::ScriptStacker, configure_static: false do
  css 'static/css'
  javascript 'static/javascript'
end

use Rack::Static, url: ['static']
```

## Serve multiple sets of files in order

```ruby
use Rack::ScriptStacker do
  css 'static/css'
  javascript 'vendor/javascript'
  javascript 'static/javascript'
end
```

## Serve files at a different path

```ruby
use Rack::ScriptStacker, configure_static: false do
  css 'css' => 'stylesheets'
  javascript 'js' => 'scripts'
end
```

## Change the template for a stacker

```ruby
use Rack::ScriptStacker,
    stackers: {
      javascript: { template: '<script src="%s"></script>' }
    } do
  javascript 'static/javascript'
end
```

## Use placeholder slots

```html
<!-- index.html //-->

<!doctype html>
<html lang="en">
    <head>
      <!-- ScriptStacker: CSS //-->
    </head>
    <body>
      <!-- ScriptStacker: JAVASCRIPT //-->
    </body>
</html>

use Rack::ScriptStacker, inject_mode: :slot do
  css 'static/css'
  javascript 'static/javascript'
end
```
