require 'rack/scriptstacker'

def smart_deindent str
  first_line_indent = str.match(/^\s*/).to_s.size
  str.gsub(/^\s{#{first_line_indent}}/, '')
end

def app_with_body body
  lambda { |env| [nil, nil, [body]] }
end

describe Rack::ScriptStacker do
  let(:js_files) { ['main.js', 'util.js'] }
  let(:css_files) { ['main.css', '_whatever.css'] }
  let(:body) { '<div>whatever</div>' }

  before :each do
    @middleware = Rack::ScriptStacker.new app_with_body(body)
    allow(@middleware).to receive(:files_for).with('javascripts/*.js').and_return(js_files)
    allow(@middleware).to receive(:files_for).with('css/*.css').and_return(css_files)
    @response = @middleware.call nil
    @response_body = @response[2][0]
  end

  it 'does not change without replacement slots' do
    expect(@response_body).to eq('<div>whatever</div>')
  end

  context 'javascript' do
    let(:body) do
      smart_deindent(<<-HTML)
        <body>
          <div>lmao</div>
          <<< JAVASCRIPT >>>
        </body>
      HTML
    end

    it 'injects tags' do
      expect(@response_body).to eq(smart_deindent(<<-HTML))
        <body>
          <div>lmao</div>
          <script type="text/javascript" src="/static/javascripts/main.js"></script>
          <script type="text/javascript" src="/static/javascripts/util.js"></script>
        </body>
      HTML
    end
  end

  context 'css' do
    let(:body) do
      smart_deindent(<<-HTML)
        <head>
          <<< CSS >>>
        </head>
      HTML
    end

    it 'injects tags' do
      expect(@response_body).to eq(smart_deindent(<<-HTML))
        <head>
          <link rel="stylesheet" type="text/css" href="/static/css/main.css" />
          <link rel="stylesheet" type="text/css" href="/static/css/_whatever.css" />
        </head>
      HTML
    end
  end
end

