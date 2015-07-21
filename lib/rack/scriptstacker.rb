require "rack/scriptstacker/version"

class String
  def smart_deindent
    first_line_indent = self.match(/^\s*/).to_s.size
    self.gsub(/^\s{#{first_line_indent}}/, '')
  end
end

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
        [replace_in_body(response[2])]
      ]
    end

    private

    def replace_in_body body
      body[0].gsub /^(\s*)<<< JAVASCRIPT >>>/ do
        indent = $1
        js_files.map do |filename|
          %Q[#{indent}<script type="text/javascript" src="/static/javascripts/#{filename}"></script>]
        end.join("\n")
      end

    end

    def js_files
    end
  end
end
