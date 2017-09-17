require 'rubygems'
require 'sinatra'
require 'multi_json'
require "sinatra/multi_route"
require 'yaml'
require "mongo"

mongo = Mongo::Client.new([ ENV.fetch('MONGO_PORT_27017_TCP_ADDR') + ":" + ENV.fetch('MONGO_PORT_27017_TCP_PORT') ], :database => 'cchecksdb')
$cks = mongo[:checks]

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
    set :raise_errors, false
    set :show_exceptions, false
  end

  # halt: error helpers
  not_found do
    halt 404, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'route not found' })
  end

  error 405 do
    halt 405, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'Method Not Allowed' })
  end

  error 500 do
    halt 500, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'server error' })
  end

  # headers
  helpers do
    def headers_get
      headers "Content-Type" => "application/json; charset=utf8"
      headers "Access-Control-Allow-Methods" => "HEAD, GET"
      headers "Access-Control-Allow-Origin" => "*"
      cache_control :public, :must_revalidate, :max_age => 60
    end
  end

  # handler - redirects any /foo -> /foo/
  #  - if has any query params, passes to handler as before
  # get %r{(/.*[^\/])$} do
  #   if request.query_string == "" or request.query_string.nil?
  #     redirect request.script_name + "#{params[:captures].first}/"
  #   else
  #     pass
  #   end
  # end

  ## routes
  get '/?' do
    headers_get
    redirect '/heartbeat'
  end

  get '/docs/?' do
    headers_get
    redirect 'https://github.com/ropensci/cchecksapi/blob/master/docs/api_docs.md', 301
  end

  get "/heartbeat/?" do
    headers_get
    $ip = request.ip
    return JSON.pretty_generate({
      "routes" => [
        "/docs (GET)",
        "/heartbeat (GET)",
        "/pkgs (GET)",
        "/pkgs/:pkg_name: (GET)"
      ]
    })
  end

  get '/pkgs/?' do
    headers_get
    begin
      lim = params[:limit] || 10
      off = params[:offset] || 0
      #d = $cdb.all_docs(:include_docs => true, :limit => lim, :skip => off)
      d = $cks.find()
      #dat = d["rows"].map { |x| x['doc'] }
      dat = d.to_a
      raise Exception.new('no results found') if d.nil?
      { found: d.count, count: dat.length, offset: nil, error: nil,
        data: dat }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/pkgs/:name/?' do
    headers_get
    begin
      #d = $cdb.get(params[:name])
      d = $cks.find({ package: params[:name] }).first
      raise Exception.new('no results found') if d.nil?
      { error: nil, data: d }.to_json
    rescue Exception => e
      halt 400, { error: { message: e.message }, data: nil }.to_json
    end
  end

  # prevent some HTTP methods
  route :post, :put, :delete, :copy, :patch, :options, :trace, '/*' do
    halt 405
  end

end
