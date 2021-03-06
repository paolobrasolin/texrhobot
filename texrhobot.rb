require 'sinatra'
require 'tmpdir'
require 'open3'
require 'json'
require 'yaml'

TEXRHOBOT_CACHE_DIR     = ENV.fetch 'TEXRHOBOT_CACHE_DIR'
TEXRHOBOT_FORMATS_DIR   = ENV.fetch 'TEXRHOBOT_FORMATS_DIR'
TEXRHOBOT_TEMPLATES_DIR = ENV.fetch 'TEXRHOBOT_TEMPLATES_DIR'

FileUtils.mkdir_p TEXRHOBOT_CACHE_DIR
FileUtils.cp Dir["#{TEXRHOBOT_FORMATS_DIR}/*.fmt"], TEXRHOBOT_CACHE_DIR

def offset_line_numbers(tex_log, offset)
  tex_log.gsub(/^l.(\d+)(.*)$/) { "l.#{$1.to_i + offset}" + $2 }
end

get '/' do
  send_file 'index.html'
end

post '/crank' do
  headers['Access-Control-Allow-Origin'] = '*'

  @yaml = params.to_yaml
  @hash = Digest::MD5.hexdigest(@yaml)
  File.open("#{TEXRHOBOT_CACHE_DIR}/#{@hash}.yaml", 'w').write(@yaml)

  renderer = ERB.new(File.read("#{TEXRHOBOT_TEMPLATES_DIR}/#{params['template']}.tex.erb"), 0, '<>')
  File.write("#{TEXRHOBOT_CACHE_DIR}/#{@hash}.tex", renderer.result(binding))

  Dir.chdir TEXRHOBOT_CACHE_DIR do
    stdout, _stderr, status = Open3.capture3(
      'texfot', 'pdftex', @hash
    )
    error 400, offset_line_numbers(stdout, -2).lines[2..-1].join unless status.success?

    _stdout, _stderr, status = Open3.capture3(
      'dvisvgm', '--no-fonts', @hash
    )
    error 500, 'dvisvgm crashed' unless status.success?
  end

  content_type :svg
  halt 200, File.read("#{TEXRHOBOT_CACHE_DIR}/#{@hash}.svg")
end
