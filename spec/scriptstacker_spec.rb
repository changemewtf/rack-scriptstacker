require 'rack/scriptstacker'

describe Rack::ScriptStacker do
  it 'replaces in body' do
    app = lambda { |env| [nil, nil, ['oi mate']] }
    middleware = Rack::ScriptStacker.new app
    response = middleware.call nil
    expect(response[2]).to eq(['oi wat'])
  end
end
