require "rack/scriptstacker/version"

class ::Hash
  def recursive_merge other
    merger = proc do |key, v1, v2|
      Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2
    end
    self.merge(other, &merger)
  end
end

module Rack
  DEFAULT_CONFIG = {
    source_prefix: 'static/',
    serve_prefix: 'static/',
    stackers: {
      javascript: {
        template: '<script type="text/javascript" src="%s"></script>',
        source_glob: 'javascripts/*.js',
        serve_path: 'javascripts/',
        slot: 'JAVASCRIPT'
      },
      css: {
        template: '<link rel="stylesheet" type="text/css" href="%s" />',
        source_glob: 'css/*.css',
        serve_path: 'css/',
        slot: 'CSS'
      }
    }
  }

  class ScriptStacker
    def initialize app, config={}
      @app = app
      @config = DEFAULT_CONFIG.recursive_merge config
    end

    def call env
      response = @app.call(env)

      if response[1]['Content-Type'] != 'text/html'
        response
      else
        [
          response[0],
          response[1],
          replace_in_body(response[2])
        ]
      end
    end

    private

    def replace_in_body body
      body.map do |chunk|
        @config[:stackers].values.reduce(chunk, &method(:file_replace))
      end
    end

    def file_replace chunk, stacker
      chunk.gsub /^(\s*)<<< #{stacker[:slot]} >>>/ do
        indent = $1
        files_for(stacker[:source_glob]).map do |filename|
          sprintf stacker[:template], serve_path(stacker[:serve_path], filename)
        end.map do |line|
          indent + line
        end.join "\n"
      end
    end

    def files_for source_glob
      Dir[@config[:source_prefix] + source_glob]
        .map { |file| ::File.basename(file) }
    end

    def serve_path path, filename
      '/' + @config[:serve_prefix] + path + filename
    end
  end
end
