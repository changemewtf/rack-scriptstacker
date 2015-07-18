require "rack/scriptstacker/version"

module Rack
  class ScriptStacker
    def initialize app
      @app = app
    end

    def call env
      response = @app.call env

      [
        response[0],
        response[1],
        replace_in_body(response[2])
      ]
    end

    private

    def replace_in_body body
      body.map do |chunk|
        chunk.gsub 'hey', 'sup yo'
      end
    end
  end
end
