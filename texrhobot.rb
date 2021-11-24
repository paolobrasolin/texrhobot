require 'sinatra'
require "sinatra/cors"
use Rack::Logger

helpers do
  def logger
    request.logger
  end
end


require 'tmpdir'
require 'open3'
require 'json'
require 'yaml'

TEXRHOBOT_CACHE_DIR     = ENV.fetch('TEXRHOBOT_CACHE_DIR')
TEXRHOBOT_FORMATS_DIR   = ENV.fetch('TEXRHOBOT_FORMATS_DIR')
TEXRHOBOT_TEMPLATES_DIR = ENV.fetch('TEXRHOBOT_TEMPLATES_DIR')

FileUtils.mkdir_p TEXRHOBOT_CACHE_DIR
FileUtils.cp Dir["#{TEXRHOBOT_FORMATS_DIR}/*.fmt"], TEXRHOBOT_CACHE_DIR

def offset_line_numbers(tex_log, offset)
  tex_log.gsub(/^l.(\d+)(.*)$/) { "l.#{$1.to_i + offset}" + $2 }
end

set :allow_origin, "https://paolobrasolin.github.io http://localhost"
set :allow_methods, "GET,HEAD,POST"

get '/' do
  erb :index, locals: {
    # see https://devcenter.heroku.com/articles/dyno-metadata
    release_created_at: ENV.fetch('HEROKU_RELEASE_CREATED_AT', "YYYY-MM-DDTHH:MM:SSZ"),
    release_version: ENV.fetch('HEROKU_RELEASE_VERSION', "v00"),
    slug_description: ENV.fetch('HEROKU_SLUG_DESCRIPTION', "Deploy 12345678"),
  }
end

post '/crank' do
  @yaml = params.to_yaml
  @hash = Digest::MD5.hexdigest(@yaml)
  File.open("#{TEXRHOBOT_CACHE_DIR}/#{@hash}.yaml", 'w').write(@yaml)

  renderer = ERB.new(File.read("#{TEXRHOBOT_TEMPLATES_DIR}/#{params['template']}.tex.erb"), 0, '<>')
  File.write("#{TEXRHOBOT_CACHE_DIR}/#{@hash}.tex", renderer.result(binding))

  Dir.chdir TEXRHOBOT_CACHE_DIR do
    stdout, stderr, status = Open3.capture3(
      'texfot', 'pdftex', @hash
    )
    logger.error stderr
    logger.info stdout
    error 400, offset_line_numbers(stdout, -2).lines[2..-1].join unless status.success?

    stdout, stderr, status = Open3.capture3(
      'dvisvgm', '--no-fonts', '--page=1', '--output=%f.svg', @hash
    )
    logger.error stderr
    logger.info stdout
    error 500, 'dvisvgm crashed' unless status.success?

    content_type :svg
    halt 200, File.read("#{@hash}.svg")
  end
end
