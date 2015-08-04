require 'cantrips/string/smart_deindent'

require 'rack/scriptstacker'

def app_with_body body
  lambda { |env| [200, {'Content-Type' => 'text/html'}, [body]] }
end

describe Rack::ScriptStacker do
  let(:js_files) { ['main.js', 'util.js'] }
  let(:vendor_js_files) { ['jquery.js', 'blogo_web.js'] }
  let(:css_files) { ['main.css', '_whatever.css'] }
  let(:config) do
    {
      configure_static: false,
      inject_mode: Rack::ScriptStacker::InjectMode::SLOT
    }
  end
  let(:stack_spec) do
    Proc.new {
      css 'static/css'
      javascript 'static/javascripts'
    }
  end
  let(:middleware) do
    Rack::ScriptStacker.new app_with_body(body), config, &stack_spec
  end

  before :each do
    allow_any_instance_of(Rack::ScriptStackerUtils::Stacker).to receive(:files_for).with('static/css/').and_return(css_files)
    allow_any_instance_of(Rack::ScriptStackerUtils::Stacker).to receive(:files_for).with('static/javascripts/').and_return(js_files)
    allow_any_instance_of(Rack::ScriptStackerUtils::Stacker).to receive(:files_for).with('vendor/javascripts/').and_return(vendor_js_files)
    if middleware
      @response = middleware.call nil
      @response_body = @response[2][0]
    end
  end

  context 'inactive' do
    let(:body) { '<div>whatever</div>' }
    it 'does not change without replacement slots' do
      expect(@response_body).to eq('<div>whatever</div>')
    end
  end

  context 'javascript' do
    let(:body) do
      <<-HTML.smart_deindent
        <body>
          <div>lmao</div>
          <!-- ScriptStacker: JAVASCRIPT //-->
        </body>
      HTML
    end
    it 'injects tags' do
      expect(@response_body).to eq(<<-HTML.smart_deindent)
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
      <<-HTML.smart_deindent
        <head>
          <!-- ScriptStacker: CSS //-->
        </head>
      HTML
    end
    it 'injects tags' do
      expect(@response_body).to eq(<<-HTML.smart_deindent)
        <head>
          <link rel="stylesheet" type="text/css" href="/static/css/main.css" />
          <link rel="stylesheet" type="text/css" href="/static/css/_whatever.css" />
        </head>
      HTML
    end
  end

  context 'multiple specs for one stacker' do
    let(:stack_spec) do
      Proc.new {
        javascript 'vendor/javascripts'
        javascript 'static/javascripts'
      }
    end
    let(:body) do
      <<-HTML.smart_deindent
        <body>
          <div>lmao</div>
          <!-- ScriptStacker: JAVASCRIPT //-->
        </body>
      HTML
    end
    it 'injects tags in order' do
      expect(@response_body).to eq(<<-HTML.smart_deindent)
        <body>
          <div>lmao</div>
          <script type="text/javascript" src="/vendor/javascripts/jquery.js"></script>
          <script type="text/javascript" src="/vendor/javascripts/blogo_web.js"></script>
          <script type="text/javascript" src="/static/javascripts/main.js"></script>
          <script type="text/javascript" src="/static/javascripts/util.js"></script>
        </body>
      HTML
    end
  end

  context 'static file auto-configuration' do
    let(:body) { '<div>whatever</div>' }
    it 'configures static automatically' do
      expect(Rack::Static).to receive(:new).with(
        duck_type(:call), {
          urls: ['/static/css/', '/static/javascripts/']
        }
      )
      Rack::ScriptStacker.new app_with_body(body), configure_static: true do
        css 'static/css'
        javascript 'static/javascripts'
      end
    end
  end

  context 'auto-inject' do
    let(:config) do
      {
        configure_static: false,
        inject_mode: Rack::ScriptStacker::InjectMode::TAG
      }
    end
    let(:body) do
      <<-HTML.smart_deindent
        <html>
          <head>
            <title>OH RLY</title>
          </head>
          <body>
            <div>ya rly</div>
          </body>
        </html>
      HTML
    end
    it 'injects before the <head> and <body> tags' do
      expect(@response_body).to eq(<<-HTML.smart_deindent)
        <html>
          <head>
            <title>OH RLY</title>
            <link rel="stylesheet" type="text/css" href="/static/css/main.css" />
            <link rel="stylesheet" type="text/css" href="/static/css/_whatever.css" />
          </head>
          <body>
            <div>ya rly</div>
            <script type="text/javascript" src="/static/javascripts/main.js"></script>
            <script type="text/javascript" src="/static/javascripts/util.js"></script>
          </body>
        </html>
      HTML
    end
  end

  context 'per-directory specs' do
    let(:config) do
      {
        configure_static: false,
        inject_mode: Rack::ScriptStacker::InjectMode::TAG
      }
    end
    let(:stack_spec) do
      Proc.new {
        directory 'static' do
          css 'css'
          javascript 'javascripts'
        end
      }
    end
    let(:body) do
      <<-HTML.smart_deindent
        <html>
          <head>
          </head>
          <body>
          </body>
        </html>
      HTML
    end
    it 'injects tags correctly' do
      expect(@response_body).to eq(<<-HTML.smart_deindent)
        <html>
          <head>
            <link rel="stylesheet" type="text/css" href="/static/css/main.css" />
            <link rel="stylesheet" type="text/css" href="/static/css/_whatever.css" />
          </head>
          <body>
            <script type="text/javascript" src="/static/javascripts/main.js"></script>
            <script type="text/javascript" src="/static/javascripts/util.js"></script>
          </body>
        </html>
      HTML
    end
  end
end

describe Rack::ScriptStackerUtils::PathSpec do
  let(:css_spec) { Rack::ScriptStackerUtils::PathSpec.new(
    'static/css/' => '/stylesheets'
  )}
  let(:js_spec) { Rack::ScriptStackerUtils::PathSpec.new(
    'static/javascripts' => 'static/js/'
  )}

  context 'serve path' do
    it 'always serves with absolute paths' do
      expect(js_spec.serve_path).to start_with('/')
    end
    it 'appends a slash when there is none, for concatenation simplicity' do
      expect(css_spec.serve_path).to end_with('/')
    end
    it 'does not prepend a redundant slash' do
      expect(css_spec.serve_path[0..1]).to_not start_with('//')
    end
    it 'does not append a redundant slash' do
      expect(js_spec.serve_path[-2..-1]).to_not end_with('//')
    end
  end

  context 'source path' do
    it 'appends a slash when there is none, for concatenation simplicity' do
      expect(js_spec.source_path).to end_with('/')
    end
    it 'does not prepend a slash, because local files are relative to pwd' do
      expect(css_spec.source_path).to_not start_with('/')
    end
    it 'does not append a redundant slash' do
      expect(css_spec.source_path).to_not end_with('//')
    end
  end
end

