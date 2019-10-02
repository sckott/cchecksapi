require 'rubygems'
require 'sinatra'
require 'multi_json'
require "sinatra/multi_route"
require 'yaml'
require 'date'
require "mongo"
require 'active_record'
require 'aws-sdk-s3'

require_relative 'badges'
require_relative 'funs'
require_relative 'history'

# mongo
mongo_host = [ ENV.fetch('MONGO_PORT_27017_TCP_ADDR') + ":" + ENV.fetch('MONGO_PORT_27017_TCP_PORT') ]
client_options = {
  :database => 'cchecksdb',
  :user => ENV.fetch('CCHECKS_MONGO_USER'),
  :password => ENV.fetch('CCHECKS_MONGO_PWD'),
  :max_pool_size => 25,
  :connect_timeout => 15,
  :wait_queue_timeout => 15
}
mongo = Mongo::Client.new(mongo_host, client_options)
# mongo = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'cchecksdb')

$cks = mongo[:checks]
$maint = mongo[:maintainer]
$cks_history = mongo[:checks_history]

# sql-mariadb
$config = YAML::load_file(File.join(__dir__, 'config.yaml'))
ActiveSupport::Deprecation.silenced = true
ActiveRecord::Base.establish_connection($config['db']['cchecks'])

Aws.config[:region] = 'us-west-2'
Aws.config[:credentials] = Aws::Credentials.new(ENV.fetch('CCHECKS_S3_WRITE_ACCESS_KEY'), ENV.fetch('CCHECKS_S3_WRITE_SECRET_KEY'))
$s3_x = Aws::S3::Resource.new(region: 'us-west-2')

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
    set :strict_paths, false
    set :server, :puma
    set :protection, :except => [:json_csrf]
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
      # sec = Time.at(Time.now.to_i + 1).httpdate
      headers 'Content-Type' => 'image/svg+xml; charset=utf-8'
      headers 'Expires' => fivemin
      # headers 'Expires' => sec
      headers 'Cache-Control' => 'max-age=300, public'
    end

    def headers_s3link
      headers "Content-Type" => "application/json; charset=utf8"
      headers "Access-Control-Allow-Methods" => "HEAD, GET"
      headers "Access-Control-Allow-Origin" => "*"
      cache_control :public, :must_revalidate, :max_age => 60
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
        "/pkgs/:pkg_name:/history (GET)",
        "/history/:date (GET)",
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
      raise Exception.new('limit must be zero or greater') unless lim >= 0
      if lim == 0
        d = $cks.count
        dat = []
      else
        d = $cks.find({}, {"limit" => lim, "skip" => off})
        dat = d.to_a
      end
      raise Exception.new('no results found') if d.nil?
      { found: lim == 0 ? d : d.count, 
        count: dat.length, 
        offset: params[:offset], 
        error: nil,
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
      raise Exception.new('limit must be zero or greater') unless lim >= 0
      if lim == 0
        d = $maint.count
        dat = []
      else
        d = $maint.find({}, {"limit" => lim, "skip" => off})
        dat = d.to_a
      end
      raise Exception.new('no results found') if d.nil?
      { found: lim == 0 ? d : d.count, 
        count: dat.length, 
        offset: params[:offset], 
        error: nil,
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


  # get '/pkghistory' do
  #   headers_get
  #   begin
  #     d = HistoryAll.endpoint(params)
  #     raise Exception.new('no results found') if d.nil?
  #     dat = d.as_json
  #     dat.map { |x| x['summary'] = MultiJson.load(x['summary']) }
  #     dat.map { |x| x['checks'] = MultiJson.load(x['checks']) }
  #     dat.map { |x| x['check_details'] = MultiJson.load(x['check_details']) }
  #     dat.map { |x| 
  #       if !x['check_details'].nil?
  #         x['check_details'] = x['check_details'].length > 0 ? x['check_details'] : nil 
  #       end
  #     }
  #     hist = dat.map { |x| { package: x["package"], history: dat.delete('package') } }
  #     { found: d.count, count: d.length, offset: params[:offset], error: nil,
  #       data: hist }.to_json
  #   rescue Exception => e
  #     halt 400, { count: 0, error: { message: e.message }, data: nil }.to_json
  #   end
  # end

  get '/pkgs/:name/history' do
    headers_get
    begin
      d = HistoryName.endpoint(params)
      raise Exception.new('no results found') if d.length.zero?
      dat = d.as_json
      dat.map { |x| x.delete('id') }
      dat.map { |x| x.delete('package') }
      dat.map { |x| x['summary'] = MultiJson.load(x['summary']) }
      dat.map { |x| x['checks'] = MultiJson.load(x['checks']) }
      dat.map { |x| x['check_details'] = MultiJson.load(x['check_details']) }
      dat.map { |x| 
        if !x['check_details'].nil?
          x['check_details'] = x['check_details'].length > 0 ? x['check_details'] : nil 
        end
      }
      hist = { package: params[:name], history: dat }
      { error: nil, data: hist }.to_json
    rescue Exception => e
      halt 400, { error: { message: e.message }, data: nil }.to_json
    end
  end

  get '/history/:date' do
    headers_s3link
    begin
      path = Date.parse(params[:date]).strftime("%Y-%m-%d") + ".json.gz"
      z = $s3_x.bucket("cchecks-history").object(path)
      url = z.presigned_url(:get)
      redirect url, { error: nil, message: "you hit a redirect. use the link in 'Location' header; or follow redirects" }.to_json
    rescue Exception => e
      halt 400, { error: { message: e.message }, data: nil }.to_json
    end
  end


  # prevent some HTTP methods
  route :post, :put, :delete, :copy, :patch, :options, :trace, '/*' do
    halt 405
  end

end
