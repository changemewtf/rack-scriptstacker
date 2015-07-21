# Rack::ScriptStacker

Glob and inject JavaScript/CSS files into served HTML.

```ruby
# config.ru

require 'rack/scriptstacker'

use Rack::ScriptStacker, {

}

run app
```
