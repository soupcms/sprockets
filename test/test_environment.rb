require 'sprockets_test'
require 'rack/mock'
require 'execjs'

module EnvironmentTests
  def self.test(name, &block)
    define_method("test_#{name.inspect}", &block)
  end

  test "working directory is the default root" do
    assert_equal Dir.pwd, @env.root
  end

  test "default logger level is set to fatal" do
    assert_equal Logger::FATAL, @env.logger.level
  end

  test "active css compressor" do
    assert_nil @env.css_compressor
  end

  test "active js compressor" do
    assert_nil @env.js_compressor
  end

  test "paths" do
    assert_equal [fixture_path("default")], @env.paths.to_a
  end

  test "register global path" do
    assert_equal [fixture_path("default")], new_environment.paths.to_a
    Sprockets.append_path(fixture_path("asset"))
    assert_equal [fixture_path("asset"), fixture_path("default")], new_environment.paths.to_a
    Sprockets.clear_paths
  end

  test "extensions" do
    ["coffee", "erb", "sass", "scss", "css", "js"].each do |ext|
      assert @env.extensions.to_a.include?(".#{ext}"), "'.#{ext}' not in #{@env.extensions.inspect}"
    end
  end

  test "engine extensions" do
    ["coffee", "erb", "sass", "scss"].each do |ext|
      assert @env.engine_extensions.include?(".#{ext}")
    end
    ["css", "js"].each do |ext|
      assert !@env.engine_extensions.include?(".#{ext}")
    end
  end

  test "format extensions" do
    ["css", "js"].each do |ext|
      assert @env.format_extensions.include?(".#{ext}")
    end
    ["coffee", "erb", "sass", "scss"].each do |ext|
      assert !@env.format_extensions.include?(".#{ext}")
    end
  end

  test "eco templates" do
    asset = @env["goodbye.jst"]
    context = ExecJS.compile(asset.to_s)
    assert_equal "Goodbye world\n", context.call("JST['goodbye']", :name => "world")
  end

  test "ejs templates" do
    asset = @env["hello.jst"]
    context = ExecJS.compile(asset.to_s)
    assert_equal "hello: world\n", context.call("JST['hello']", :name => "world")
  end

  test "asset_data_uri helper" do
    asset = @env["with_data_uri.css"]
    assert_equal "body {\n  background-image: url(data:image/gif;base64,R0lGODlhAQABAIAAAP%2F%2F%2FwAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw%3D%3D) no-repeat;\n}\n", asset.to_s
  end

  test "lookup mime type" do
    assert_equal "application/javascript", @env.mime_types(".js")
    assert_equal "application/javascript", @env.mime_types("js")
    assert_equal "text/css", @env.mime_types(:css)
    assert_equal nil, @env.mime_types("foo")
    assert_equal nil, @env.mime_types("foo")
  end

  test "lookup bundle processors" do
    assert_equal 0, @env.bundle_processors('application/javascript').size
    assert_equal 1, @env.bundle_processors('text/css').size
  end

  test "lookup compressors" do
    silence_warnings do
      require 'sprockets/sass_compressor'
    end
    assert_equal 'Sprockets::SassCompressor', @env.compressors['text/css'][:sass].name
    assert_equal 'Sprockets::UglifierCompressor', @env.compressors['application/javascript'][:uglifier].name
  end

  test "resolve absolute path in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(fixture_path('default/gallery.js'))
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve(fixture_path('default/coffee/foo.coffee'))
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve(fixture_path('default/jquery.tmpl.min.js'))

    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(fixture_path('default/gallery.js'), content_type: 'application/javascript')
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve(fixture_path('default/coffee/foo.coffee'), content_type: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve(fixture_path('default/jquery.tmpl.min.js'), content_type: 'application/javascript')

    assert_raises(Sprockets::FileOutsidePaths) do
      @env.resolve("/bin/sh")
    end

    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/gallery.js'), content_type: 'text/css')
    end
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/coffee/foo.coffee'), content_type: 'text/css')
    end
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/gallery.foo'))
    end
  end

  test "resolve in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js")
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(Pathname.new("gallery.js"))
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve("coffee/foo.js")
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min")
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min.js")

    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("null")
    end
  end

  test "resolve content type in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js")
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js", content_type: "application/javascript")
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery", content_type: "application/javascript")
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve('coffee/foo', content_type: 'application/javascript')
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve('coffee/foo.coffee', content_type: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min", content_type: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min.js", content_type: 'application/javascript')

    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("gallery.js", content_type: "text/css")
    end
  end

  test "resolve bower special case" do
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower")
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower.js")
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower", content_type: 'application/javascript')
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower.js", content_type: 'application/javascript')
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("bower.css", content_type: 'text/css')
    end

    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit")
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit.js")
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit", content_type: 'application/javascript')
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit.js", content_type: 'application/javascript')
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.resolve("qunit.css")
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.resolve("qunit", content_type: 'text/css')
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.resolve("qunit.css", content_type: 'text/css')
  end

  test "find bundled asset in environment" do
    assert_equal "var Gallery = {};\n", @env["gallery.js"].to_s
  end

  test "find bundled asset with absolute path environment" do
    assert_equal "var Gallery = {};\n", @env[fixture_path("default/gallery.js")].to_s
  end

  test "find bundled asset with implicit format" do
    assert_equal "(function() {\n  var foo;\n\n  foo = 'hello';\n\n}).call(this);\n",
      @env["coffee/foo.js"].to_s
  end

  test "find static asset in environment" do
    assert_equal "Hello world\n", @env["hello.txt"].to_s
  end

  test "find static asset with leading slash in environment" do
    assert_equal "Hello world\n", @env[fixture_path("default/hello.txt")].to_s
  end

  test "find index.js in directory" do
    assert_equal "var A;\nvar B;\n", @env["mobile.js"].to_s
  end

  test "find index.css in directory" do
    assert_equal ".c {}\n.d {}\n/*\n\n */\n\n", @env["mobile.css"].to_s
  end

  test "find bower.json in directory" do
    assert_equal "var bower;\n", @env["bower.js"].to_s
  end

  test "find multiple bower.json in directory" do
    assert_equal "var qunit;\n", @env["qunit.js"].to_s
    assert_equal ".qunit {}\n", @env["qunit.css"].to_s
  end

  test "missing static path returns nil" do
    assert_nil @env[fixture_path("default/missing.png")]
  end

  test "find static directory returns nil" do
    assert_nil @env["images"]
  end

  test "missing asset returns nil" do
    assert_equal nil, @env["missing.js"]
  end

  test "missing asset path returns nil" do
    assert_nil @env[fixture_path("default/missing.js")]
  end

  test "asset with missing requires raises an exception" do
    assert_raises Sprockets::FileNotFound do
      @env["missing_require.js"]
    end
  end

  test "asset with missing depend_on raises an exception" do
    assert_raises Sprockets::FileNotFound do
      @env["missing_depend_on.js"]
    end
  end

  test "asset with missing absolute depend_on raises an exception" do
    assert_raises Sprockets::FileOutsidePaths do
      @env["missing_absolute_depend_on.js"]
    end
  end

  test "asset logical path for absolute path" do
    assert_equal "gallery.js",
      @env[fixture_path("default/gallery.js")].logical_path
    assert_equal "application.js",
      @env[fixture_path("default/application.js.coffee")].logical_path
    assert_equal "mobile/a.js",
      @env[fixture_path("default/mobile/a.js")].logical_path
  end

  ENTRIES_IN_PATH = 44

  test "iterate over each entry" do
    entries = []
    @env.recursive_stat(fixture_path("default")) do |path, stat|
      entries << path
    end
    assert_equal ENTRIES_IN_PATH, entries.length

    @env.recursive_stat(fixture_path("errors")) do |path, stat|
    end
  end

  FILES_IN_PATH = 37

  test "iterate over each logical path" do
    paths = []
    @env.find_logical_paths do |logical_path|
      paths << logical_path
    end
    assert_equal FILES_IN_PATH, paths.length
    assert_equal paths.size, paths.uniq.size, "has duplicates"

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert paths.include?("coffee/index.js")
    assert !paths.include?("coffee")
  end

  test "iterate over each logical path and filename" do
    paths = []
    filenames = []
    @env.find_logical_paths do |logical_path, filename|
      paths << logical_path
      filenames << filename
    end
    assert_equal FILES_IN_PATH, paths.length
    assert_equal paths.size, paths.uniq.size, "has duplicates"

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert paths.include?("coffee/index.js")
    assert !paths.include?("coffee")

    assert filenames.any? { |p| p =~ /application.js.coffee/ }
  end

  test "find logical path enumerator" do
    enum = @env.find_logical_paths
    assert_kind_of String, enum.first
    assert_equal FILES_IN_PATH, enum.to_a.length
  end

  test "iterate over each logical path matching fnmatch filters" do
    paths = []
    @env.find_logical_paths("*.js") do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matches index files" do
    paths = []
    @env.find_logical_paths("coffee.js") do |logical_path|
      paths << logical_path
    end
    assert paths.include?("coffee.js")
    assert !paths.include?("coffee/index.js")
  end

  test "each logical path enumerator matching fnmatch filters" do
    paths = []
    enum = @env.find_logical_paths("*.js")
    enum.to_a.each do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matching regexp filters" do
    paths = []
    @env.find_logical_paths(/.*\.js/) do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matching proc filters" do
    paths = []
    @env.find_logical_paths(proc { |fn| File.extname(fn) == '.js' }) do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matching proc filters with full path arg" do
    paths = []
    @env.find_logical_paths(proc { |_, fn| fn.match(fixture_path('default/mobile')) }) do |logical_path|
      paths << logical_path
    end

    assert paths.include?("mobile/a.js")
    assert paths.include?("mobile/b.js")
    assert !paths.include?("application.js")
  end

  test "CoffeeScript files are compiled in a closure" do
    script = @env["coffee"].to_s
    assert_equal "undefined", ExecJS.exec(script)
  end

  test "logical path" do
    assert_raises Sprockets::FileOutsidePaths do
      @env.logical_path_for(fixture_path("missing/application.js"))
    end

    assert_equal "application.js", @env.logical_path_for(fixture_path("default/application.js"))
    assert_equal "application.css", @env.logical_path_for(fixture_path("default/application.css"))
    assert_equal "jquery.foo.min.js", @env.logical_path_for(fixture_path("default/jquery.foo.min.js"))

    assert_equal "application.js", @env.logical_path_for(fixture_path("default/application.js.erb"))
    assert_equal "application.js", @env.logical_path_for(fixture_path("default/application.js.coffee"))
    assert_equal "application.css", @env.logical_path_for(fixture_path("default/application.css.scss"))

    assert_equal "application.js", @env.logical_path_for(fixture_path("default/application.coffee"))
    assert_equal "application.css", @env.logical_path_for(fixture_path("default/application.scss"))
    assert_equal "hello.js", @env.logical_path_for(fixture_path("default/hello.jst.ejs"))
  end
end

class WhitespaceProcessor
  def self.call(input)
    input[:data].gsub(/\s+/, "")
  end
end

class WhitespaceCompressor
  def self.compress(source)
    source.gsub(/\s+/, "")
  end
end

class TestEnvironment < Sprockets::TestCase
  include EnvironmentTests

  def new_environment
    Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
      env.cache = {}
      yield env if block_given?
    end
  end

  def setup
    @env = new_environment
  end

  test "changing logger" do
    @env.logger = Logger.new($stderr)
  end

  test "changing paths" do
    @env.clear_paths
    @env.append_path(fixture_path('asset'))
  end

  test "register mime type" do
    assert !@env.mime_types("jst")
    @env.register_mime_type("application/javascript", "jst")
    assert_equal "application/javascript", @env.mime_types("jst")
  end

  test "register bundle processor" do
    old_size = @env.bundle_processors('text/css').size
    @env.register_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size+1, @env.bundle_processors('text/css').size
  end

  test "register compressor" do
    assert !@env.compressors['text/css'][:whitespace]
    @env.register_compressor 'text/css', :whitespace, WhitespaceCompressor
    assert @env.compressors['text/css'][:whitespace]
  end

  test "register global block preprocessor" do
    old_size = new_environment.preprocessors('text/css').size
    Sprockets.register_preprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, new_environment.preprocessors('text/css').size
    Sprockets.unregister_preprocessor('text/css', :foo)
    assert_equal old_size, new_environment.preprocessors('text/css').size
  end

  test "unregister custom block preprocessor" do
    old_size = @env.preprocessors('text/css').size
    @env.register_preprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, @env.preprocessors('text/css').size
    @env.unregister_preprocessor('text/css', :foo)
    assert_equal old_size, @env.preprocessors('text/css').size
  end

  test "unregister custom block postprocessor" do
    old_size = @env.postprocessors('text/css').size
    @env.register_postprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, @env.postprocessors('text/css').size
    @env.unregister_postprocessor('text/css', :foo)
    assert_equal old_size, @env.postprocessors('text/css').size
  end

  test "register global block postprocessor" do
    old_size = new_environment.postprocessors('text/css').size
    Sprockets.register_postprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, new_environment.postprocessors('text/css').size
    Sprockets.unregister_postprocessor('text/css', :foo)
    assert_equal old_size, new_environment.postprocessors('text/css').size
  end

  test "unregister custom block bundle processor" do
    old_size = @env.bundle_processors('text/css').size
    @env.register_bundle_processor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, @env.bundle_processors('text/css').size
    @env.unregister_bundle_processor('text/css', :foo)
    assert_equal old_size, @env.bundle_processors('text/css').size
  end

  test "register global bundle processor" do
    old_size = Sprockets.bundle_processors('text/css').size
    Sprockets.register_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size+1, Sprockets.bundle_processors('text/css').size

    env = new_environment
    assert_equal old_size+1, env.bundle_processors('text/css').size

    Sprockets.unregister_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size, Sprockets.bundle_processors('text/css').size
  end

  test "setting css compressor to nil clears current compressor" do
    @env.css_compressor = WhitespaceCompressor
    assert @env.css_compressor
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "setting js compressor to nil clears current compressor" do
    @env.js_compressor = WhitespaceCompressor
    assert @env.js_compressor
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting js compressor to template handler" do
    assert_nil @env.js_compressor
    @env.js_compressor = Sprockets::UglifierCompressor
    assert_equal Sprockets::UglifierCompressor, @env.js_compressor
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting css compressor to template handler" do
    silence_warnings do
      require 'sprockets/sass_compressor'
    end
    assert_nil @env.css_compressor
    @env.css_compressor = Sprockets::SassCompressor
    assert_equal Sprockets::SassCompressor, @env.css_compressor
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "setting js compressor to sym" do
    assert_nil @env.js_compressor
    @env.js_compressor = :uglifier
    assert_equal 'Sprockets::UglifierCompressor', @env.js_compressor.name
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting css compressor to sym" do
    silence_warnings do
      require 'sprockets/sass_compressor'
    end
    assert_nil @env.css_compressor
    @env.css_compressor = :sass
    assert_equal 'Sprockets::SassCompressor', @env.css_compressor.name
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "changing digest implementation class" do
    old_digest = @env.digest
    old_asset_digest = @env["gallery.js"].digest

    @env.digest_class = Digest::MD5

    assert old_digest != @env.digest
    assert old_asset_digest != @env["gallery.js"].digest
  end

  test "changing digest version" do
    old_digest = @env.digest
    old_asset_digest = @env["gallery.js"].digest

    @env.version = 'v2'

    assert old_digest != @env.digest
    assert old_asset_digest != @env["gallery.js"].digest
  end

  test "bundled asset is stale if its mtime is updated or deleted" do
    filename = File.join(fixture_path("default"), "tmp.js")

    sandbox filename do
      assert_nil @env["tmp.js"]

      File.open(filename, 'w') { |f| f.puts "foo;" }
      assert_equal "foo;\n", @env["tmp.js"].to_s

      File.open(filename, 'w') { |f| f.puts "bar;" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "bar;\n", @env["tmp.js"].to_s

      File.unlink(filename)
      assert_nil @env["tmp.js"]
    end
  end

  test "static asset is stale if its mtime is updated or deleted" do
    filename = File.join(fixture_path("default"), "tmp.png")

    sandbox filename do
      assert_nil @env["tmp.png"]

      File.open(filename, 'w') { |f| f.puts "foo" }
      assert_equal "foo\n", @env["tmp.png"].to_s

      File.open(filename, 'w') { |f| f.puts "bar" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "bar\n", @env["tmp.png"].to_s

      File.unlink(filename)
      assert_nil @env["tmp.png"]
    end
  end

  test "bundled asset cached if theres an error building it" do
    @env.cache = nil

    filename = File.join(fixture_path("default"), "tmp.coffee")

    sandbox filename do
      File.open(filename, 'w') { |f| f.puts "-->" }
      begin
        @env["tmp.js"].to_s
      rescue ExecJS::Error => e
        assert e
      else
        flunk "nothing raised"
      end

      File.open(filename, 'w') { |f| f.puts "->" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "(function() {\n  (function() {});\n\n}).call(this);\n", @env["tmp.js"].to_s
    end
  end

  test "seperate contexts classes for each instance" do
    e1 = new_environment
    e2 = new_environment

    assert_raises(NameError) { e1.context_class.instance_method(:foo) }
    assert_raises(NameError) { e2.context_class.instance_method(:foo) }

    e1.context_class.class_eval do
      def foo; end
    end

    e1.context_class.instance_method(:foo)
    assert_raises(NameError) { e2.context_class.instance_method(:foo) }
  end

  test "registering engine adds to the environments extensions" do
    assert !@env.engines[".foo"]
    assert !@env.extensions.include?(".foo")

    @env.register_engine ".foo", Sprockets::ERBTemplate

    assert @env.engines[".foo"]
    assert @env.extensions.include?(".foo")
  end

  test "seperate engines for each instance" do
    e1 = new_environment
    e2 = new_environment

    assert_nil e1.engines[".foo"]
    assert_nil e2.engines[".foo"]

    e1.register_engine ".foo", Sprockets::ERBTemplate

    assert e1.engines[".foo"]
    assert_nil e2.engines[".foo"]
  end

  test "disabling default directive preprocessor" do
    @env.unregister_preprocessor('application/javascript', Sprockets::DirectiveProcessor)
    assert_equal "// =require \"notfound\"\n;\n", @env["missing_require.js"].to_s
  end
end

class TestIndex < Sprockets::TestCase
  include EnvironmentTests

  def new_environment
    Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
      env.cache = {}
      yield env if block_given?
    end.index
  end

  def setup
    @env = new_environment
  end

  test "does not allow new mime types to be added" do
    assert_raises TypeError do
      @env.register_mime_type "application/javascript", ".jst"
    end
  end

  test "change in environment mime types does not affect index" do
    env = Sprockets::Environment.new(".")
    env.register_mime_type "application/javascript", ".jst"
    index = env.index

    assert_equal "application/javascript", index.mime_types("jst")
    env.register_mime_type nil, ".jst"
    assert_equal "application/javascript", index.mime_types("jst")
  end

  test "does not allow new bundle processors to be added" do
    assert_raises TypeError do
      @env.register_bundle_processor 'text/css', WhitespaceProcessor
    end
  end

  test "does not allow bundle processors to be removed" do
    assert_raises TypeError do
      @env.unregister_bundle_processor 'text/css', WhitespaceProcessor
    end
  end

  test "change in environment bundle_processors does not affect index" do
    env = Sprockets::Environment.new(".")
    index = env.index

    assert !index.bundle_processors('text/css').include?(WhitespaceProcessor)
    env.register_bundle_processor 'text/css', WhitespaceProcessor
    assert !index.bundle_processors('text/css').include?(WhitespaceProcessor)
  end

  test "does not allow css compressor to be changed" do
    assert_raises TypeError do
      @env.css_compressor = WhitespaceCompressor
    end
  end

  test "does not allow js compressor to be changed" do
    assert_raises TypeError do
      @env.js_compressor = WhitespaceCompressor
    end
  end

  test "change in environment engines does not affect index" do
    env = Sprockets::Environment.new
    index = env.index

    assert_nil env.engines[".foo"]
    assert_nil index.engines[".foo"]

    env.register_engine ".foo", Sprockets::ERBTemplate

    assert env.engines[".foo"]
    assert_nil index.engines[".foo"]
  end
end
