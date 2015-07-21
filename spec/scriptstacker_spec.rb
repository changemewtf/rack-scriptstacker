require 'rack/scriptstacker'

def app_with_body body
  lambda { |env| [nil, nil, [body]] }
end

describe Rack::ScriptStacker do
  it 'injects javascript tags' do
    finder = lambda { ['main.js', 'util.js'] }

    middleware = Rack::ScriptStacker.new app_with_body(<<-HTML), finder
<body>
<div>lmao</div>
<!-- ScriptStacker: JavaScript //-->
</body>
    HTML

    response = middleware.call nil

    expect(response[2][0]).to eq(<<-HTML)
<body>
<div>lmao</div>
<script type="text/javascript" src="/static/javascripts/main.js"></script>
<script type="text/javascript" src="/static/javascripts/util.js"></script>
</body>
    HTML
  end

end

