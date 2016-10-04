require 'sinatra'
require 'open3'
require 'json'
require 'yaml'

CACHE_DIR = '.tex-cache'.freeze
FileUtils.mkdir_p CACHE_DIR
FileUtils.cp Dir['*.fmt'], CACHE_DIR

get '/' do
  send_file 'index.html'
end

post '/crank' do
  headers['Access-Control-Allow-Origin'] = '*'

  @yaml = params.to_yaml
  @hash = Digest::MD5.hexdigest(@yaml)
  File.open("#{CACHE_DIR}/#{@hash}.yaml", 'w') do |file|
    file.write(@yaml)
  end

  renderer = ERB.new(File.read('template.tex.erb'), 0, '<>')
  File.write("#{CACHE_DIR}/#{@hash}.tex", renderer.result(binding))

  Dir.chdir CACHE_DIR do
    _stdout, _stderr, status = Open3.capture3(
      'texfot', 'pdftex', @hash
    )
    error 400, _stdout unless status.success?

    _stdout, _stderr, status = Open3.capture3(
      'dvisvgm', '--no-fonts', @hash
    )
    error 500, 'dvisvgm crashed' unless status.success?
  end

  content_type :svg
  halt 200, File.read("#{CACHE_DIR}/#{@hash}.svg")
end
