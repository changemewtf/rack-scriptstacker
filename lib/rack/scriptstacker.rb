require 'rack'

require 'cantrips/hash/recursive_merge'

require 'rack/scriptstacker/version'

module Rack
  class ScriptStacker
    module InjectMode
      TAG = :tag
      SLOT = :slot
    end

    DEFAULT_CONFIG = {
      configure_static: true,
      inject_mode: InjectMode::TAG,
      stackers: {
        css: {
          template: '<link rel="stylesheet" type="text/css" href="%s" />',
          glob: '*.css',
          slot: 'CSS',
          inject_before_tag: '</head>',
        },
        javascript: {
          template: '<script type="text/javascript" src="%s"></script>',
          glob: '*.js',
          slot: 'JAVASCRIPT',
          inject_before_tag: '</body>',
        }
      }
    }

    def initialize app, config={}, &stack_spec
      @config = DEFAULT_CONFIG.recursive_merge config
      @path_specs = ScriptStackerUtils::SpecSolidifier.new(
        @config[:stackers].keys
      ).call stack_spec
      @runner = ScriptStackerUtils::Runner.new(
        @config[:stackers],
        @config[:inject_mode]
      )
      @app = @config[:configure_static] ? configure_static(app) : app
    end

    def call env
      response = @app.call env

      if response[1]['Content-Type'] != 'text/html'
        response
      else
        [
          response[0],
          response[1],
          @runner.replace_in_body(response[2], @path_specs)
        ]
      end
    end

    private

    def configure_static app
      Rack::Static.new app, {
        urls: @path_specs
          .values
          .reduce([]) { |memo, specs| memo + specs }
          .select { |spec| spec.paths_identical? }
          .map { |spec| spec.serve_path }
      }
    end
  end

  module ScriptStackerUtils
    class SpecSolidifier < BasicObject
      def initialize stacker_names, directory=nil
        @stacker_names = stacker_names
        @specs = ::Hash.new { |hash, key|  hash[key] = [] }
        @directory = directory
      end

      def call stack_spec
        instance_eval &stack_spec
        @specs
      end

      def directory dir_name, &block
        SpecSolidifier.new(@stacker_names, dir_name).call(block)
          .each do |stacker_name, specs|
            @specs[stacker_name] += specs
          end
      end

      def method_missing name, *args
        if !@stacker_names.include? name
          ::Kernel.raise ::ArgumentError.new(
            "Expected one of #{@stacker_names}, but got #{name.inspect}."
          )
        end
        if args.size != 1
          ::Kernel.raise ::ArgumentError.new(
            "Expected a path spec like 'static/css' => 'stylesheets', " +
            "but got #{args.inspect} instead."
          )
        end

        if @directory
          path = "#{@directory}/#{args[0]}"
        else
          path = args[0]
        end

        @specs[name].push ::Rack::ScriptStackerUtils::PathSpec.new(path)
      end
    end

    class PathSpec
      def initialize paths
        if paths.respond_to? :key
          # this is just for pretty method calls, eg.
          # css 'stylesheets' => 'static/css'
          @source_path, @serve_path = paths.to_a.flatten
        else
          # if only one path is given, use the same for both;
          # this is just like how Rack::Static works
          @source_path = @serve_path = paths
        end
      end

      def source_path
        normalize_end_slash @source_path
      end

      def serve_path
        normalize_end_slash normalize_begin_slash(@serve_path)
      end

      def paths_identical?
        # Paths are normalized differently, so this check isn't doable from
        # outside the instance; but we still want to know if they're basically
        # the same so we can easily configure Rack::Static to match.
        @source_path == @serve_path
      end

      private

      def normalize_end_slash path
        path.end_with?('/') ? path : path + '/'
      end

      def normalize_begin_slash path
        path.start_with?('/') ? path : '/' + path
      end
    end

    class Runner
      def initialize stacker_configs, inject_mode
        @stackers = stacker_configs.map do |name, config|
          [name, Stacker.new(config)]
        end.to_h
        @inject_mode = inject_mode
      end

      def replace_in_body body, path_specs
        path_specs.each do |name, specs|
          specs.each do |spec|
            @stackers[name].find_files spec.source_path, spec.serve_path
          end
        end

        body.map do |chunk|
          @stackers.values.reduce chunk do |memo, stacker|
            inject_into memo, stacker
          end
        end
      end

      private

      def inject_into chunk, stacker
        case @inject_mode
        when Rack::ScriptStacker::InjectMode::SLOT
          stacker.replace_slot chunk
        when Rack::ScriptStacker::InjectMode::TAG
          stacker.tag_inject chunk
        else
          raise ArgumentError.new "Unexpected InjectMode #{@inject_mode.inspect}."
        end
      end
    end

    class Stacker
      def initialize config
        @template = config[:template]
        @glob = config[:glob]
        @slot = config[:slot]
        @inject_before_tag = config[:inject_before_tag]

        @files = []
      end

      def find_files source_path, serve_path
        @files = @files + files_for(source_path).map do |filename|
          sprintf @template, serve_path + filename
        end
      end

      def tag_inject chunk
        lines = chunk.split "\n", -1 # this preserves any trailing newlines
        index = lines.find_index { |line| line.match @inject_before_tag }
        return if index.nil?
        indent = lines[index].match(/^\s*/).to_s
        (
          lines[0...index] +
          file_list(indent + '  ') +
          lines[index..-1]
        ).join "\n"
      end

      def replace_slot chunk
        chunk.gsub /^(\s*)#{slot}/ do
          file_list($1).join "\n"
        end
      end

      private

      def file_list indent
        @files.map do |line|
          indent + line
        end
      end

      def slot
        "<!-- ScriptStacker: #{@slot} //-->"
      end

      def files_for source_path
        Dir[source_path + @glob]
          .map { |file| ::File.basename(file) }
      end
    end
  end
end
