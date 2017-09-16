require 'rubygems'
require 'sinatra'
require 'multi_json'
require "sinatra/multi_route"
require 'yaml'

require_relative "utils"

$config = YAML::load_file(File.join(__dir__, 'config.yaml'))

ActiveSupport::Deprecation.silenced = true
val = ENV['SSH_CLIENT']
if val.to_s == ''
  ActiveRecord::Base.establish_connection($config['db']['localhost'])
else
  ActiveRecord::Base.establish_connection($config['db']['ec2'])
end

class CCAPI < Sinatra::Application
  register Sinatra::MultiRoute

  # before do
  #   # puts '[ENV]'
  #   # p ENV
  #   puts '[Params]'
  #   p params
  #   # puts '[body]'
  #   # p JSON.parse(request.body.read)
  # end

  ## configuration
  configure do
    set :raise_errors, true
    set :show_exceptions, true
  end

  # halt: error helpers
  # error 400 do
  #   halt 400, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'malformed request' })
  # end

  error 401 do
    halt 401, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'unauthorized' })
  end

  not_found do
    halt 404, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'route not found' })
  end

  error 405 do
    halt 405, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'Method Not Allowed' })
  end

  error 500 do
    halt 500, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'server error' })
  end

  # headers and auth helpers
  helpers do
    def headers_get
      headers "Content-Type" => "application/json; charset=utf8"
      headers "Access-Control-Allow-Methods" => "HEAD, GET"
      headers "Access-Control-Allow-Origin" => "*"
      cache_control :public, :must_revalidate, :max_age => 60
    end

    def headers_auth
      headers "Content-Type" => "application/json; charset=utf8"
      headers "Access-Control-Allow-Methods" => "HEAD, GET, POST, PUT, DELETE"
      headers "Access-Control-Allow-Origin" => "*"
      cache_control :public, :must_revalidate, :max_age => 60
    end

    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ENV['ROAPI_USER'], ENV['ROAPI_PWD']]
    end
  end

  # handler - redirects any /foo -> /foo/
  #  - if has any query params, passes to handler as before
  get %r{(/.*[^\/])$} do
    if request.query_string == "" or request.query_string.nil?
      redirect request.script_name + "#{params[:captures].first}/"
    else
      pass
    end
  end

  ## routes
  get '/?' do
    headers_get
    redirect '/heartbeat'
  end

  get '/docs/?' do
    headers_get
    redirect 'https://github.com/ropensci/roapi/wiki', 301
  end

  get "/heartbeat/?" do
    headers_get
    $ip = request.ip
    return JSON.pretty_generate({
      "routes" => [
        "/docs (GET)",
        "/heartbeat (GET)",
        "/repos (GET)",
        "/repos/:repo_name: (GET) (POST, PUT, DELETE [auth])",
        "/repos/:repo_name:/github (GET)",
        "/repos/:repo_name:/travis (GET)",
        "/repos/:repo_name:/appveyor (GET)",
        "/repos/:repo_name:/cranlogs (GET)",
        "/repos/:repo_name:/cran (GET)",
        "/repos/:repo_name:/dependencies (GET)",
        "/repos/:repo_name:/citations (GET)",
        "/repos/:repo_name:/groupings (GET)",
        "/repos/:repo_name:/categories (GET)",
        "/categories (GET)",
        "/groupings (GET)"
      ]
    })
  end

  get '/repos/?' do
    headers_get
    begin
      data = get_repo(params)
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/repos/:name/?' do
    headers_get
    begin
      data = get_repo(params)
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  # routes to get individual tables
  get '/repos/:name/github/?' do
    headers_get
    begin
      data = get_repo_table('github')
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/repos/:name/travis/?' do
    headers_get
    begin
      data = get_repo_table('travis')
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/repos/:name/appveyor/?' do
    headers_get
    begin
      data = get_repo_table('appveyor')
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/repos/:name/cranlogs/?' do
    headers_get
    begin
      data = get_repo_table('cranlogs')
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/repos/:name/cran/?' do
    headers_get
    begin
      data = get_repo_table('cran')
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  # dependencies and reverse dependencies
  get '/repos/:name/dependencies/?' do
    headers_get
    begin
      data = get_repo_deps()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  # citations
  get '/repos/:name/citations/?' do
    headers_get
    begin
      data = get_repo_citations()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end


  # groupings
  get '/repos/:name/groupings/?' do
    headers_get
    begin
      data = get_repo_groupings()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/groupings/?' do
    headers_get
    begin
      data = get_all_groupings()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/groupings/:grouping/?' do
    headers_get
    begin
      data = get_groupings()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end


  # categories
  get '/repos/:name/categories/?' do
    headers_get
    begin
      data = get_repo_categories()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/categories/?' do
    headers_get
    begin
      data = get_all_categories()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/categories/:category/?' do
    headers_get
    begin
      data = get_categories()
      raise Exception.new('no results found') if data.length.zero?
      { count: data.length, error: nil, data: data }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  # prevent some HTTP methods
  route :copy, :patch, :options, :trace, '/*' do
    halt 405
  end

end
