require 'active_record'
require 'aws-sdk-s3'
require 'ndjson'
require_relative 'history'

# s3 connection
Aws.config[:region] = 'us-west-2'
Aws.config[:credentials] = Aws::Credentials.new(ENV.fetch('CCHECKS_S3_WRITE_ACCESS_KEY'), ENV.fetch('CCHECKS_S3_WRITE_SECRET_KEY'))
$s3_x = Aws::S3::Resource.new(region: 'us-west-2')

# sql connection
$config = YAML::load_file(File.join(__dir__, 'config.yaml'))
ActiveSupport::Deprecation.silenced = true
ActiveRecord::Base.establish_connection($config['db']['cchecks'])

## History model for querying by date
class HistoryDate < ActiveRecord::Base
  self.table_name = 'histories'
  def self.query(date)
    fields = %w(package summary checks check_details date_updated)
    select(fields.join(', '))
      .where("DATE(date_updated) = '%s'" % date)
  end
end

# class HistoryDate2 < ActiveRecord::Base
#   self.table_name = 'histories'
#   def self.query(date)
#     fields = %w(package)
#     select(fields.join(', '))
#       .where("DATE(date_updated) = '%s'" % date)
#   end
# end

# fme, takes 5 minutes to get data for one date
# hmmmmmmmmm
# 

def write_history(date)
  puts "pulling data from MariaDB"
  z = HistoryDate.query(date); nil
  puts "converting to Ruby Hash"
  data = z.as_json; nil

  puts "writing file to disk"
  json_file = date + ".json"
  nd = NDJSON::Generator.new json_file
  data.each do |x|; nil
    nd.write(x); nil
  end; nil

  # compress json file
  compress_file(json_file)
  json_file_gz = json_file + ".gz"

  # upload
  puts "uploading to S3"
  obj = $s3_x.bucket("cchecks-history").object(json_file_gz)
  obj.upload_file(json_file_gz)
end

# write_history('2019-06-02')
# dates = ["3", "4", "5"].map { |z| "2019-05-0" + z }
# (1.month.ago.to_date..Date.today).map{ |date| date.strftime("%Y-%m-%d") }
# Time.now.beginning_of_month - 1.day
# dates = ("2019-05-01".to_date..Time.now.beginning_of_month).map{ |date| date.strftime("%Y-%m-%d") }
# dates = ("2019-01-01".to_date.."2019-01-31".to_date).map{ |date| date.strftime("%Y-%m-%d") }
dates = ["2018-12-18",("2018-12-20".to_date.."2018-12-31".to_date).map{ |date| date.strftime("%Y-%m-%d") }].flatten
dates.each do |z| 
  write_history(z)
end
