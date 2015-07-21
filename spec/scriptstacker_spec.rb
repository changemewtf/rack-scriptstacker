require 'rack/scriptstacker'

def app_with_body body
  lambda { |env| [nil, nil, [body]] }
end

describe Rack::ScriptStacker do
  it 'injects javascript tags' do
    middleware = Rack::ScriptStacker.new app_with_body(<<-HTML.smart_deindent)
      <body>
        <div>lmao</div>
        <<< JAVASCRIPT >>>
      </body>
    HTML

    allow(middleware).to receive(:js_files).and_return(['main.js', 'util.js'])
    response = middleware.call nil

    expect(response[2][0]).to eq(<<-HTML.smart_deindent)
      <body>
        <div>lmao</div>
        <script type="text/javascript" src="/static/javascripts/main.js"></script>
        <script type="text/javascript" src="/static/javascripts/util.js"></script>
      </body>
    HTML
  end

end

