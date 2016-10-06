require 'sinatra'
require 'open3'
require 'json'
require 'yaml'

TMP_DIR = '.cache'.freeze # cache folder
TPL_DIR = 'templates'.freeze # templates folder
FMT_DIR = 'formats'.freeze # formats folder

def offset_line_numbers(tex_log, offset)
  tex_log.gsub(/^l.(\d+)(.*)$/) { "l.#{$1.to_i + offset}" + $2 }
end

FileUtils.mkdir_p TMP_DIR
FileUtils.cp Dir["#{FMT_DIR}/*.fmt"], TMP_DIR

get '/' do
  send_file 'index.html'
end

post '/crank' do
  headers['Access-Control-Allow-Origin'] = '*'

  @yaml = params.to_yaml
  @hash = Digest::MD5.hexdigest(@yaml)
  File.open("#{TMP_DIR}/#{@hash}.yaml", 'w').write(@yaml)

  renderer = ERB.new(File.read("#{TPL_DIR}/#{params['template']}.tex.erb"), 0, '<>')
  File.write("#{TMP_DIR}/#{@hash}.tex", renderer.result(binding))

  Dir.chdir TMP_DIR do
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
  halt 200, File.read("#{TMP_DIR}/#{@hash}.svg")
end
