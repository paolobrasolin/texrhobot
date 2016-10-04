require 'sinatra'
require 'json'
require 'yaml'
require 'open3'

CACHE_DIR = '.tex-cache'.freeze
FileUtils.mkdir_p CACHE_DIR
FileUtils.cp Dir['*.fmt'], CACHE_DIR

before do
  headers['Access-Control-Allow-Origin'] = '*'
  # headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
  # headers['Access-Control-Allow-Headers'] = 'accept, authorization, origin'
  # content_type :json
end

post '/' do
  @yaml = params.to_yaml
  @hash = Digest::MD5.hexdigest(@yaml)
  File.open("#{CACHE_DIR}/#{@hash}.yaml", 'w') do |file|
    file.write(@yaml)
  end

  renderer = ERB.new(File.read('template.tex.erb'), 0, '<>')
  File.write("#{CACHE_DIR}/#{@hash}.tex", renderer.result(binding))

  Dir.chdir CACHE_DIR do
    _stdout, _stderr, status = Open3.capture3(
      'pdftex', '-interaction=nonstopmode', @hash
    )
    halt 500 unless status.success?

    _stdout, _stderr, status = Open3.capture3(
      'dvisvgm', '--no-fonts', @hash
    )
    halt 500 unless status.success?
  end

  content_type :svg
  halt 200, File.read("#{CACHE_DIR}/#{@hash}.svg")
end
