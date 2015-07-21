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
        chunk.gsub /^(\s*)<<< JAVASCRIPT >>>/ do
          indent = $1
          js_files.map do |filename|
            %Q[#{indent}<script type="text/javascript" src="/static/javascripts/#{filename}"></script>]
          end.join("\n")
        end.gsub /^(\s*)<<< CSS >>>/ do
          indent = $1
          css_files.map do |filename|
            %Q[#{indent}<link rel="stylesheet" type="text/css" href="/static/css/#{filename}" />]
          end.join("\n")
        end
      end
    end

    def js_files
    end

    def css_files
    end
  end
end
