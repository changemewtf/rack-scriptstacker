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

    JS_TEMPLATE = '<script type="text/javascript" src="/static/javascripts/%<filename>s"></script>'
    CSS_TEMPLATE = '<link rel="stylesheet" type="text/css" href="/static/css/%<filename>s" />'

    def replace_in_body body
      body.map do |chunk|
        chunk = file_replace(chunk, js_files, 'JAVASCRIPT', JS_TEMPLATE)
        chunk = file_replace(chunk, css_files, 'CSS', CSS_TEMPLATE)
        chunk
      end
    end

    def file_replace chunk, files, slot, template
      chunk.gsub /^(\s*)<<< #{slot} >>>/ do
        indent = $1
        files.map do |filename|
          sprintf "#{indent}#{template}", filename: filename
        end.join("\n")
      end
    end

    def js_files
    end

    def css_files
    end
  end
end
