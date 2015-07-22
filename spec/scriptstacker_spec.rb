require 'rack/scriptstacker'

def smart_deindent str
  first_line_indent = str.match(/^\s*/).to_s.size
  str.gsub(/^\s{#{first_line_indent}}/, '')
end

def app_with_body body
  lambda { |env| [200, {'Content-Type' => 'text/html'}, [body]] }
end

describe Rack::ScriptStacker do
  let(:js_files) { ['main.js', 'util.js'] }
  let(:vendor_js_files) { ['jquery.js', 'buttscript.js'] }
  let(:css_files) { ['main.css', '_whatever.css'] }
  let(:middleware) do
    Rack::ScriptStacker.new app_with_body(body) do
      css 'static/css'
      javascript 'static/javascripts'
    end
  end

  before :each do
    allow_any_instance_of(Rack::Stacker).to receive(:files_for).with('static/css/').and_return(css_files)
    allow_any_instance_of(Rack::Stacker).to receive(:files_for).with('static/javascripts/').and_return(js_files)
    allow_any_instance_of(Rack::Stacker).to receive(:files_for).with('vendor/javascripts/').and_return(vendor_js_files)
    @response = middleware.call nil
    @response_body = @response[2][0]
  end

  context 'inactive' do
    let(:body) { '<div>whatever</div>' }

    it 'does not change without replacement slots' do
      expect(@response_body).to eq('<div>whatever</div>')
    end
  end

  context 'javascript' do
    let(:body) do
      smart_deindent(<<-HTML)
        <body>
          <div>lmao</div>
          <!-- ScriptStacker: JAVASCRIPT //-->
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
          <!-- ScriptStacker: CSS //-->
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

  context 'path normalization' do
    let(:middleware) do
      Rack::ScriptStacker.new app_with_body(body) do
        css 'static/css/' => '/stylesheets'
        javascript 'static/javascripts' => 'static/js'
      end
    end
    let(:body) do
      smart_deindent(<<-HTML)
        <!-- ScriptStacker: CSS //-->
        <!-- ScriptStacker: JAVASCRIPT //-->
      HTML
    end

    it 'does not mess up the paths' do
      expect(@response_body).to eq(smart_deindent(<<-HTML))
        <link rel="stylesheet" type="text/css" href="/stylesheets/main.css" />
        <link rel="stylesheet" type="text/css" href="/stylesheets/_whatever.css" />
        <script type="text/javascript" src="/static/js/main.js"></script>
        <script type="text/javascript" src="/static/js/util.js"></script>
      HTML
    end
  end

  context 'multiple specs for one stacker' do
    let(:middleware) do
      Rack::ScriptStacker.new app_with_body(body) do
        javascript 'vendor/javascripts'
        javascript 'static/javascripts'
      end
    end
    let(:body) do
      smart_deindent(<<-HTML)
        <body>
          <div>lmao</div>
          <!-- ScriptStacker: JAVASCRIPT //-->
        </body>
      HTML
    end

    it 'injects tags in order' do
      expect(@response_body).to eq(smart_deindent(<<-HTML))
        <body>
          <div>lmao</div>
          <script type="text/javascript" src="/vendor/javascripts/jquery.js"></script>
          <script type="text/javascript" src="/vendor/javascripts/buttscript.js"></script>
          <script type="text/javascript" src="/static/javascripts/main.js"></script>
          <script type="text/javascript" src="/static/javascripts/util.js"></script>
        </body>
      HTML
    end
  end
end

