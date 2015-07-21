require "rack/scriptstacker/version"

class ScriptFinder
end

module Rack
  class ScriptStacker
    def initialize app, finder=nil
      @app = app
      @finder = finder || ScriptFinder.new
    end

    def call env
      response = @app.call env

      [
        response[0],
        response[1],
        [replace_in_body(response[2])]
      ]
    end

    private

    def replace_in_body body
      body[0].gsub '<!-- ScriptStacker: JavaScript //-->' do
        @finder.call.map do |filename|
          '<script type="text/javascript" src="/static/javascripts/' + filename + '"></script>'
        end.join("\n")
      end
    end
  end
end
