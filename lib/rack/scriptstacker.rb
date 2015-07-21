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
    stackers: {
      css: {
        template: '<link rel="stylesheet" type="text/css" href="%s" />',
        glob: '*.css',
        slot: 'CSS'
      },
      javascript: {
        template: '<script type="text/javascript" src="%s"></script>',
        glob: '*.js',
        slot: 'JAVASCRIPT'
      }
    }
  }

  class ScriptStacker
    def initialize app, config={}, &stack_spec
      @app = app
      @config = DEFAULT_CONFIG.recursive_merge config
      @stack_spec = stack_spec
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
      StackSpecRunner.new(body).run_specs @stack_spec, @config[:stackers]
    end
  end

  class StackSpecRunner
    def initialize body
      @body = body
    end

    def run_specs stack_spec, stacker_configs
      stackers = stacker_configs.map do |name, config|
        Stacker.new(config).tap do |stacker|
          eigenclass = class << self; self; end
          eigenclass.send :define_method, name do |paths|
            if paths.respond_to? :key
              # this is just for pretty method calls, eg.
              # css 'stylesheets' => 'static/css'
              source_path, serve_path = paths.to_a.flatten
            else
              # if only one path is given, use the same for both;
              # this is just like how Rack::Static works
              source_path = serve_path = paths
            end
            stacker.find_files source_path, serve_path
          end
        end
      end

      instance_eval &stack_spec

      @body.map do |chunk|
        stackers.reduce chunk do |memo, stacker|
          stacker.replace_slot(memo)
        end
      end
    end
  end

  class Stacker
    def initialize config
      @template = config[:template]
      @glob = config[:glob]
      @slot = config[:slot]
      @files = []
    end

    def find_files source_path, serve_path
      source_path += '/' if !source_path.end_with? '/'
      serve_path += '/' if !serve_path.end_with? '/'
      serve_path = '/' + serve_path if !serve_path.start_with? '/'
      @files = @files + files_for(source_path).map do |filename|
        sprintf @template, serve_path + filename
      end
    end

    def replace_slot chunk
      chunk.gsub /^(\s*)<<< #{@slot} >>>/ do
        indent = $1
        @files.map do |line|
          indent + line
        end.join "\n"
      end
    end

    private

    def files_for source_path
      Dir[source_path + @glob]
        .map { |file| ::File.basename(file) }
    end
  end
end
