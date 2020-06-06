require "mongo"
require 'active_record'
require 'date'
require 'aws-sdk-s3'
require 'ndjson'
require_relative 'utils'

# mongo connection
mongo_host = [ ENV.fetch('MONGO_PORT_27017_TCP_ADDR') + ":" + ENV.fetch('MONGO_PORT_27017_TCP_PORT') ]
client_options = {
  :database => 'cchecksdb',
  :user => ENV.fetch('CCHECKS_MONGO_USER'),
  :password => ENV.fetch('CCHECKS_MONGO_PWD'),
  :max_pool_size => 25,
  :connect_timeout => 15,
  :wait_queue_timeout => 15
}
$mongo = Mongo::Client.new(mongo_host, client_options)
# $mongo = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'cchecksdb')
$cks = $mongo[:checks]
$cks_history = $mongo[:checks_history]

# s3 connection
Aws.config[:region] = 'us-west-2'
Aws.config[:credentials] = Aws::Credentials.new(ENV.fetch('CCHECKS_S3_WRITE_ACCESS_KEY'), ENV.fetch('CCHECKS_S3_WRITE_SECRET_KEY'))
$s3_x = Aws::S3::Resource.new(region: 'us-west-2')
# $s3 = S3::Service.new(
#   :access_key_id => ENV.fetch('CCHECKS_S3_WRITE_ACCESS_KEY'),
#   :secret_access_key => ENV.fetch('CCHECKS_S3_WRITE_SECRET_KEY'))

# sql connection
$config = YAML::load_file(File.join(__dir__, 'config.yaml'))
ActiveSupport::Deprecation.silenced = true
ActiveRecord::Base.establish_connection($config['db']['cchecks'])

## create History model
class HistoryName < ActiveRecord::Base
  self.table_name = 'histories'

  def self.endpoint(params)
    fields = %w(package summary checks check_details date_updated)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 50)') unless (params[:limit] || 0) <= 50

    select(fields.join(', '))
      .where(package: params[:name])
      .order('date_updated DESC')
      .limit(params[:limit] || 10)
      .offset(params[:offset])
  end
end

def bool?(x)
  ['true', 'false'].include?(x.to_s.downcase)
end

def true?(obj)
  obj.to_s.downcase == "true"
end

class Search < ActiveRecord::Base
  self.table_name = 'histories'

  def self.endpoint(params)
    allowed_fields = %w(package summary checks check_details date_updated)

    if not params[:fields].nil?
      fields = params[:fields].split(',')
      fields.each { |x|
        raise Exception.new('%s not in allowed set' % x) unless allowed_fields.include?(x)
      }
    else
      fields = allowed_fields
    end
    # add required fields we want in the output
    fields = fields.union(['package', 'date_updated'])

    params.delete_if { |k, v| v.nil? || v.empty? }

    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 50)') unless (params[:limit] || 0) <= 50
    if !params[:one_each].nil?
      raise Exception.new('one_each must be a boolean (true/false)') unless bool?(params[:one_each])
    end

    if params[:package]
      select(fields.join(', '))
        .where('MATCH(check_details) AGAINST(?) AND package = ?', params[:q], params[:package])
        .limit(params[:limit] || 10)
        .offset(params[:offset])
    else
      if true?(params[:one_each])
        select(fields.join(', '))
          .where('MATCH(check_details) AGAINST(?)', params[:q])
          .group(:package)
          .limit(params[:limit] || 10)
          .offset(params[:offset])
      else
        select(fields.join(', '))
          .where('MATCH(check_details) AGAINST(?)', params[:q])
          .limit(params[:limit] || 10)
          .offset(params[:offset])
      end
    end
  end
end

class Hist < ActiveRecord::Base
  self.table_name = 'histories'
end

class HistoryUniqueDays < ActiveRecord::Base
  self.table_name = 'histories'
  def self.count
    select('DISTINCT date_updated')
  end
end

class HistoryOldestDayData < ActiveRecord::Base
  self.table_name = 'histories'
  def self.fetch
    where(date_updated: maximum('date_updated'))
  end
end

class HistoryOlderThan30Days < ActiveRecord::Base
  self.table_name = 'histories'
  def self.fetch
    where("date_updated < ?", 30.days.ago)
  end
  def self.delete_all
    where("date_updated < ?", 30.days.ago)
      .delete_all
  end
end

# class HistoryAll < ActiveRecord::Base
#   self.table_name = 'histories'
#
#   def self.endpoint(params)
#     fields = %w(package summary checks check_details date_updated)
#     params.delete_if { |k, v| v.nil? || v.empty? }
#     params = check_limit_offset(params)
#     raise Exception.new('limit too large (max 50)') unless (params[:limit] || 0) <= 50
#
#     select(fields.join(', '))
#       .limit(params[:limit] || 10)
#       .offset(params[:offset])
#   end
# end

def history
  # get current data from mongodb
  pkgs = hist_get_pkgs; nil

  # add data to sql db
  ## seems to take about 40 sec
  pkgs.each do |z|
    if z['check_details'].nil?
      deets = nil
    else
      if !z['check_details']['details'][0]['output'].nil?
        z['check_details']['details'].map { |e| e['output'] = e['output'].slice(0,5000) }
      end
      deets = z['check_details']
    end
    HistoryName.create(
      package: z['package'], 
      summary: z['summary'].to_json, 
      checks: z['checks'].to_json, 
      check_details: deets.to_json, 
      date_updated: z['date_updated']
    )
  end; nil
end

def hist_get_pkgs
  dat = $cks.find({}).to_a;
  return dat
end

def check_limit_offset(params)
  %i(limit offset).each do |p|
    unless params[p].nil?
      begin
        params[p] = Integer(params[p])
      rescue ArgumentError
        raise Exception.new("#{p.to_s} is not an integer")
      end
    end
  end
  return params
end

# SQL model
# ActiveRecord::Schema.define do
#   self.verbose = true

#   create_table(:histories, force: false) do |t|
#     t.string      :package,       null: false
#     t.text        :summary,       null: false
#     t.text        :checks,        null: false
#     t.text        :check_details, null: true
#     t.datetime    :date_updated,  null: false
#   end
# end

# pkg = pkgs[0]
# pkg['package']
## ONE AT A TIME
# History.create(
#   package: pkg['package'], 
#   summary: pkg['summary'], 
#   checks: pkg['checks'], 
#   check_details: pkg['check_details'], 
#   date_updated: pkg['date_updated']
# )

## MANY AT ONCE
# pkgs.each do |z|
#   deets = z['check_details'].nil? ? nil : z['check_details'].slice(0,10000)
#   History.create(
#     package: z['package'], 
#     summary: z['summary'], 
#     checks: z['checks'], 
#     check_details: deets, 
#     date_updated: z['date_updated']
#   )
# end; nil

# example create new entry
# ChecksHistory.new(
#   name: "A3",
#   summary: '{"any":false,"ok":12,"note":0,"warn":0,"error":0,"fail":0}', 
#   checks: '[{"flavor":"r-devel-linux-x86_64-debian-clang","version":"1.0.0","tinstall":1.5,"tcheck":22.71,"ttotal":24.21,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-devel-linux-x86_64-debian-clang/A3-00check.html"},{"flavor":"r-devel-linux-x86_64-debian-gcc","version":"1.0.0","tinstall":1.03,"tcheck":17.05,"ttotal":18.08,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-devel-linux-x86_64-debian-gcc/A3-00check.html"},{"flavor":"r-devel-linux-x86_64-fedora-clang","version":"1.0.0","tinstall":0.0,"tcheck":0.0,"ttotal":29.91,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-devel-linux-x86_64-fedora-clang/A3-00check.html"},{"flavor":"r-devel-linux-x86_64-fedora-gcc","version":"1.0.0","tinstall":0.0,"tcheck":0.0,"ttotal":31.69,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-devel-linux-x86_64-fedora-gcc/A3-00check.html"},{"flavor":"r-devel-windows-ix86+x86_64","version":"1.0.0","tinstall":4.0,"tcheck":54.0,"ttotal":58.0,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-devel-windows-ix86+x86_64/A3-00check.html"},{"flavor":"r-patched-linux-x86_64","version":"1.0.0","tinstall":1.32,"tcheck":21.89,"ttotal":23.21,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-patched-linux-x86_64/A3-00check.html"},{"flavor":"r-patched-solaris-x86","version":"1.0.0","tinstall":0.0,"tcheck":0.0,"ttotal":41.9,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-patched-solaris-x86/A3-00check.html"},{"flavor":"r-release-linux-x86_64","version":"1.0.0","tinstall":1.31,"tcheck":22.74,"ttotal":24.05,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-release-linux-x86_64/A3-00check.html"},{"flavor":"r-release-windows-ix86+x86_64","version":"1.0.0","tinstall":4.0,"tcheck":45.0,"ttotal":49.0,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-release-windows-ix86+x86_64/A3-00check.html"},{"flavor":"r-release-osx-x86_64","version":"1.0.0","tinstall":0.0,"tcheck":0.0,"ttotal":0.0,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-release-osx-x86_64/A3-00check.html"},{"flavor":"r-oldrel-windows-ix86+x86_64","version":"1.0.0","tinstall":6.0,"tcheck":45.0,"ttotal":51.0,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-oldrel-windows-ix86+x86_64/A3-00check.html"},{"flavor":"r-oldrel-osx-x86_64","version":"1.0.0","tinstall":0.0,"tcheck":0.0,"ttotal":0.0,"status":"OK","check_url":"https://www.R-project.org/nosvn/R.check/r-oldrel-osx-x86_64/A3-00check.html"}]', 
#   check_details: null, 
#   date_updated: "2018-11-16 21:03:59 UTC"
# )

def compress_file(file_name)
  zipped = "#{file_name}.gz"
  Zlib::GzipWriter.open(zipped) do |gz|
    gz.write IO.binread(file_name)
  end
end
# compress_file("2019-06-04.json")
# compress_file("2019-06-05.json")

# History Caching
# - get most recent days (current or previous) history
# - then writes to a ND-JSON file
# - push up the ND-JSON file to Amazon S3
# - delete that history data from the SQL DB
# note: manually need to write the current history DB data to disk 
# note: in theory, once manual cleaning out is done, we'll always have
#  about 30 days of history, with the oldest day being pruned out 
#  each day and sent up to S3
def cache_history
  x = HistoryOldestDayData.fetch; nil
  data = x.as_json; nil

  tod_ay = DateTime.now.strftime("%Y-%m-%d")
  json_file = DateTime.now.strftime("%Y-%m-%d") + ".json"
  nd = NDJSON::Generator.new json_file
  # write each package's data to disk
  # - before writing, remove auto-generated id column
  data.each do |x|; nil
    nd.write(x.except("id")); nil
  end; nil

  # compress json file
  compress_file(json_file)
  json_file_gz = json_file + ".gz"

  # upload
  # - set content-type: application/json
  # - set content-encoding: gzip
  obj = $s3_x.bucket("cchecks-history").object(json_file_gz)
  obj.upload_file(json_file_gz,
    :content_type => "application/json",
    :content_encoding => "gzip")

  # delete ndjson file on disk
  File.delete(json_file)
  File.delete(json_file_gz)
end

# Delete all data older than 30 days
def delete_history_older_than_30_days
  HistoryOlderThan30Days.delete_all; nil
end
