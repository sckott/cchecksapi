require 'rubygems'
require 'sinatra'
require 'multi_json'
require "sinatra/multi_route"
require 'yaml'
require "mongo"

require_relative 'badges'
require_relative 'funs'

mongo = Mongo::Client.new([ ENV.fetch('MONGO_PORT_27017_TCP_ADDR') + ":" + ENV.fetch('MONGO_PORT_27017_TCP_PORT') ], :database => 'cchecksdb')
# mongo = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'cchecksdb')
$cks = mongo[:checks]
$maint = mongo[:maintainer]

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
    set :strict_paths, false
    set :server, :puma
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

    def badge_headers_get
      fivemin = Time.at(Time.now.to_i + (5 * 60)).httpdate
      sec = Time.at(Time.now.to_i + 1).httpdate
      headers 'Content-Type' => 'image/svg+xml; charset=utf-8'
      # headers 'Expires' => fivemin
      headers 'Expires' => sec
      headers 'Cache-Control' => 'max-age=300, public'
    end
  end

  ## routes
  get '/' do
    headers_get
    redirect '/heartbeat'
  end

  get '/docs' do
    headers_get
    redirect 'https://github.com/ropensci/cchecksapi/blob/master/docs/api_docs.md', 301
  end

  get "/heartbeat" do
    headers_get
    $ip = request.ip
    return JSON.pretty_generate({
      "routes" => [
        "/docs (GET)",
        "/heartbeat (GET)",
        "/pkgs (GET)",
        "/pkgs/:pkg_name: (GET)",
        "/maintainers (GET)",
        "/maintainers/:email: (GET)",
        "/badges/:type/:package (GET)",
        "/badges/:flavor/:package (GET)"
      ]
    })
  end

  get '/pkgs' do
    headers_get
    begin
      %i(limit offset).each do |p|
        unless params[p].nil?
          begin
            params[p] = Integer(params[p])
          rescue ArgumentError
            raise Exception.new("#{p.to_s} is not an integer")
          end
        end
      end
      lim = (params[:limit] || 10).to_i
      off = (params[:offset] || 0).to_i
      raise Exception.new('limit too large (max 1000)') unless lim <= 1000
      d = $cks.find({}, {"limit" => lim, "skip" => off})
      dat = d.to_a
      raise Exception.new('no results found') if d.nil?
      { found: d.count, count: dat.length, offset: nil, error: nil,
        data: dat }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/pkgs/:name' do
    headers_get
    begin
      d = $cks.find({ package: params[:name] }).first
      raise Exception.new('no results found') if d.nil?
      { error: nil, data: d }.to_json
    rescue Exception => e
      halt 400, { error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/maintainers' do
    headers_get
    begin
      %i(limit offset).each do |p|
        unless params[p].nil?
          begin
            params[p] = Integer(params[p])
          rescue ArgumentError
            raise Exception.new("#{p.to_s} is not an integer")
          end
        end
      end
      lim = (params[:limit] || 10).to_i
      off = (params[:offset] || 0).to_i
      raise Exception.new('limit too large (max 1000)') unless lim <= 1000
      d = $maint.find({}, {"limit" => lim, "skip" => off})
      dat = d.to_a
      raise Exception.new('no results found') if d.nil?
      { found: d.count, count: dat.length, offset: nil, error: nil,
        data: dat }.to_json
    rescue Exception => e
      halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/maintainers/:email' do
    headers_get
    begin
      d = $maint.find({ email: params[:email] }).first
      raise Exception.new('no results found') if d.nil?
      { error: nil, data: d }.to_json
    rescue Exception => e
      halt 400, { error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/badges/:type/:package' do
    type = params[:type]
    package = params[:package]
    d = $cks.find({ package: package }).first
    if type == "summary"
      badge_headers_get
      do_badge(package, params, d)
    elsif type == "worst"
      badge_headers_get
      do_badge_worst(package, params, d)
    else
      mssg = "we only support type=summary|worst"
      headers_get
      halt 400, { error: { message: mssg }, data: nil }.to_json
    end
  end

  get '/badges/flavor/:flavor/:package' do
    badge_headers_get
    flavor = params[:flavor]
    package = params[:package]
    ignore = as_bool(params[:ignore])
    d = $cks.find({ package: package }).first
    do_badge_flavor(package, flavor, ignore, d)
  end

  # prevent some HTTP methods
  route :post, :put, :delete, :copy, :patch, :options, :trace, '/*' do
    halt 405
  end

end
