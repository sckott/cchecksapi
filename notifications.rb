require 'mongo'
require 'active_record'
require 'date'
require 'multi_json'
require 'redis'
require_relative 'email'
require_relative 'history'
require_relative 'job'

# Rules ------
#
# All components of a rule (e.g., status or time) are combined with 'AND'. That is,
# if `status="WARN"` and `regex="foo bar"`, the rule is "triggered" only if both
# of `status="WARN"` and `regex="foo bar"` components match the cran checks data.
# If you want achieve 'OR' behavior make multiple rules.
#
#
#
# status (str): match against check status. one of: ok, note, warn, error, fail
# time (int): days in a row the match occurs. an integer. can only go 30 days
#   back (history cleaned up after 30 days)
# platforms (str/int): platform the status occurs on, including negation (e.g., "-solaris"). options:
#   solaris, osx, linux, windows, devel, release, patched, oldrel
# regex (str): a regex to match against the text of an error in check_details.output
#
# e.g.'s in words, and their equivalents as a Ruby hash
# - ERROR for 3 days in a row across 2 or more platforms
#  {'status' => 'error', 'time' => 3, 'platforms' => 2, 'regex' => nil}
# - ERROR for 2 days in a row on all osx platforms
#  {'status' => 'error', 'time' => 2, 'platforms' => "osx", 'regex' => nil}
# - ERROR for 2 days in a row on all release R versions
#  {'status' => 'error', 'time' => 2, 'platforms' => "release", 'regex' => nil}
# - WARN for 4 days in a row on any platform except Solaris
#  {'status' => 'warn', 'time' => 4, 'platforms' => "-solaris", 'regex' => nil}
# - WARN for 2 days in a row across 9 or more platforms
#  {'status' => 'warn', 'time' => 2, 'platforms' => 10, 'regex' => nil}
# - NOTE across all osx platforms
#  {'status' => 'note', 'time' => nil, 'platforms' => "osx", 'regex' => nil}
# - NOTE
#  {'status' => 'note', 'time' => nil, 'platforms' => nil, 'regex' => nil}
# - error details contain regex 'install'
#  {'status' => nil, 'time' => nil, 'platforms' => nil, 'regex' => "install"}

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
mongo = Mongo::Client.new(mongo_host, client_options)
$cks = mongo[:checks]
$cks_history = mongo[:checks_history]

# sql connection
$config = YAML::load_file(File.join(__dir__, 'config.yaml'))
ActiveSupport::Deprecation.silenced = true
ActiveRecord::Base.establish_connection($config['db']['cchecks'])

# redis config
host = ENV.fetch('REDIS_PORT_6379_TCP_ADDR', 'localhost')
port = ENV.fetch('REDIS_PORT_6379_TCP_PORT', 6379)
$redis = Redis.new(host: host, port: port)

############ SQL methods ############
def history_query(params)
  d = HistoryName.endpoint(params)
  return nil if d.length.zero?
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
  return hist
end

def arel_empty?(z)
  return false if z.is_a? Arel::Table
  return false if z.is_a? Arel::Nodes::Equality
  return false if z.is_a? Arel::Nodes::And
  return true if z.nil?
  return true
end

## SQL methods
class User < ActiveRecord::Base
  self.table_name = 'user'
  has_many :rules
  def self.id(id:)
    where(id: id)
  end
  def self.list
    select("email").all
  end
end

# Rule.joins(:user).where(user: { email: "myrmecocystus@gmail.com" } )
class Rule < ActiveRecord::Base
  self.table_name = 'rule'
  belongs_to :user

  def self.fetch(email: nil, package: nil, status: nil,
    platforms: nil, time: nil, regex: nil)

    if [email, package, status, platforms, time, regex].compact.empty?
      Rule.where
    else
      id = nil
      if email
        id = User.where(email: email).ids[0] if email
        if id.nil?
          return []
        end
      end
      x = Rule.arel_table
      rel = x[:user_id].eq(id) if id
      rel = nil unless rel
      rel = (arel_empty?(rel) ? x[:package].eq(package) : rel.and(x[:package].eq(package))) if package
      rel = (arel_empty?(rel) ? x[:rule_status].eq(status) : rel.and(x[:rule_status].eq(status))) if status
      rel = (arel_empty?(rel) ? x[:rule_platforms].eq(platforms) : rel.and(x[:rule_platforms].eq(platforms))) if platforms
      rel = (arel_empty?(rel) ? x[:rule_time].eq(time) : rel.and(x[:rule_time].eq(time))) if time
      rel = (arel_empty?(rel) ? x[:rule_regex].eq(regex) : rel.and(x[:rule_regex].eq(regex))) if regex
      Rule.where(rel)
    end
  end
  def self.id(id:)
    where(id: id)
  end
end


# list all users
# users_list()
def users_list
  User.list.as_json.pluck('email').uniq
end
# add a user
# user_add(email: "myrmecocystus@gmail.com", token: "0b834e29e13d59c15810b39d396e53c1")
# user_get(email: "myrmecocystus@gmail.com")
def user_add(email:, token:)
  User.create!(email: email, token: token)
end
# get a user by email
# user_get(email: "myrmecocystus@gmail.com")
def user_get(email:)
  User.where(email: email)
end
# delete a user
# BEWARE: deletes any rules associated with that user
# user_delete(email: "myrmecocystus@gmail.com")
def user_delete(email:)
  User.where(email: email).destroy_all
end

# rules_find()
# rules_find(email: "myrmecocystus@gmail.com")
# rules_find(email: "myrmecocystus@gmail.com", package: "rgbif")
# rules_find(package: "rgbif")
# rules_find(email: "joe@stuff.com")
# rules_find(status: "note")
# rules_find(status: "warn")
# rules_find(status: "error", time: 3)
# rules_find(time: 3)
# rules_find(time: 7)
# rules_find(regex: "install failure")
def rules_find(email: nil, package: nil, status: nil, platforms: nil, time: nil, regex: nil)
  Rule.fetch(email: email, package: package, status: status, platforms: platforms, time: time, regex: regex)
end
# add a rule
# S: 'error', T: 3, P: => 2, R: nil
# S: 'warn', T: 4, P: => '-solaris', R: nil
# S: nil, T: nil, P: => nil, R: 'install'
# rules = [
#   {'status' => 'error', 'time' => 3, 'platforms' => 2, 'regex' => nil},
#   {'status' => 'warn', 'time' => 4, 'platforms' => '-solaris', 'regex' => nil},
#   {'status' => nil, 'time' => nil, 'platforms' => nil, 'regex' => 'install'}
# ]
# rules_add(email: 'myrmecocystus@gmail.com', package: 'rgbif', rules: rules)
# spocc_rules = [{'status' => 'error', 'time' => 4, 'platforms' => 5, 'regex' => nil}]
# rules_add(email: 'myrmecocystus@gmail.com', package: 'spocc', rules: spocc_rules)
# my_rules = [{'status' => 'note', 'time' => nil, 'platforms' => nil, 'regex' => nil}]
# rules_add(email: 'myrmecocystus@gmail.com', package: 'charlatan', rules: my_rules)
# # should fail - email not found
# rules_add(email: 'myrmecocystus2@gmail.com', package: 'charlatan', rules: my_rules)
def rules_add(email:, package:, rules:)
  # get user
  ug = user_get(email: email).first.as_json
  raise Exception.new("user with email '%s' not found" % email) unless ug
  # add each rule
  out = []
  rules.each do |w|
    # check that rule doesn't exist already
    z = rules_find(email:email, package:package, status:w['status'],
      platforms:w['platforms'], time:w['time'], regex:w['regex'])
    if z.empty?
      # rule doesn't exist, create rule
      tmp = Rule.create!(
        user_id: ug['id'],
        package: package,
        rule_status: w['status'],
        rule_time: w['time'],
        rule_platforms: w['platforms'],
        rule_regex: w['regex']
      )
      out << {"existed" => false, "result" => tmp}
    else
      # rule exists, return hash
      out << {"existed" => true, "result" => z[0]}
    end
  end
  return out
end
# rules_delete(id: )
# rules_find(email: 'myrmecocystus@gmail.com').length # => 3
# 
# user_add(email: "joe@stuff.com", token: "b902cd9750f107441b0654319f345aca")
# rules_add(email: 'joe@stuff.com', package: 'aaaaa', rules: [{'status' => 'error', 'time' => 3, 'platforms' => 2, 'regex' => nil}])
# rules_find(email: "joe@stuff.com")
# rules_delete(email: 'joe@stuff.com')
# rules_find(email: "joe@stuff.com")
# 
# rules_add(email: 'joe@stuff.com', package: 'aaaaa', rules: [{'status' => 'error', 'time' => 3, 'platforms' => 2, 'regex' => nil}])
# rules_find(email: "joe@stuff.com")
# rules_delete(package: 'aaaaa')
# rules_find(email: "joe@stuff.com")
#
# # by id
# rules_add(email: 'joe@stuff.com', package: 'bbb', rules: [{'status' => nil, 'time' => nil, 'platforms' => nil, 'regex' => "cheese"}])
# rules_find(email: "joe@stuff.com")
# id = rules_find(regex: "cheese").ids[0]
# rules_delete(id: id)
# rules_find(email: "joe@stuff.com")
# Rule.id(id: id)
def rules_delete(email: nil, package: nil, id: nil)
  if id.nil?
    if not email.nil? and package.nil?
      ug = user_get(email: email).first.as_json
      raise Exception.new("user with email '%s' not found" % email) unless ug
      rules_find(email: email).destroy_all
    elsif email.nil? and not package.nil?
      Rule.where(package: package).destroy_all
    end
  else
    Rule.where(id: id).destroy_all
  end
end
########################################

# CheckRule.new('WARN')
# CheckRule.new('NOTE')
# CheckRule.new('ERROR')
# x = CheckRule.new('ERROR')
# some_check = {"checks" => {"status" => "ERROR"}}
# x.check some_check
# some_check = {"checks" => {"status" => "WARN"}}
# x.check some_check
# CheckRule.new('ERROR', 'r-release-windows-ix86+x86_64')
class CheckRule
  attr_accessor :package, :status, :flavor, :flavor_original, :time, :regex, :doc, :docfirst
  def initialize(rule, doc)
    @package = rule["package"]
    # @status = rule["rule_status"].nil? ? raise("status can not be nil") : rule["rule_status"] 
    @status = rule["rule_status"]
    @flavor = rule["rule_platforms"]
    # @flavor = flavor.nil? ? "all" : flavor
    @time = rule["rule_time"]
    @regex = rule["rule_regex"]
    @doc = doc[:history]
    @docfirst = doc[:history].max_by {|z| z['date_updated']}
  end

  def check
    res_sft = self.check_status_flavor_time
    res_regex = self.check_regex # ready
    [res_sft, res_regex].compact.any?
  end

  def check_status_flavor_time
    if self.flavor.nil? and self.time.nil?
      # platform/flavor nil, time nil
      if self.status.nil?
        return self.docfirst['summary']['any']
      else
        z = self.docfirst['summary'][self.status.downcase] > 0
        return z
      end
    elsif self.flavor.nil? and not self.time.nil?
      # platform/flavor nil, time NOT nil
      if self.status.nil?
        docs = self.doc[0..(self.time - 1)];
        return docs.map { |x| x["summary"].any? }.all?
      else
        docs = self.doc[0..(self.time - 1)];
        z = docs.map {|x| x['summary'][self.status.downcase] > 0}.any?
        return z
      end
    elsif not self.flavor.nil? and self.time.nil?
      # platform/flavor NOT nil, time nil
      if self.status.nil?
        return self.docfirst['checks'].select {|w| w["flavor"].match(self.flavor)}.map {|m|
          ['note', 'warn', 'error', 'fail'].include? m["status"].downcase
        }.any?
      else
        return self.docfirst['checks'].select {|w| w["flavor"].match(self.flavor)}.map {|m|
          m["status"].downcase == self.status.downcase
        }.any?
      end
    elsif not self.flavor.nil? and not self.time.nil?
      # platform/flavor NOT nil, time NOT nil
      if self.status.nil?
        docs = self.doc[0..(self.time - 1)];
        z = docs.map {|x| x['checks'].select {|m| m["flavor"].match?(self.flavor) }.map { |e| 
           ['note', 'warn', 'error', 'fail'].include? e["status"].downcase
         }.any?
        }.all?
        return z
      else
        docs = self.doc[0..(self.time - 1)];
        z = docs.map {|x| x['checks'].select {|m| m["flavor"].match?(self.flavor) }.map { |e| 
           e["status"].downcase == self.status.downcase
         }.any?
        }.all?
        return z
      end
    else
      # not sure how to proceed, just return false to not send more emails
      return false
    end
  end

  def check_regex
    if !self.regex.nil?
      chkd = self.docfirst["check_details"]
      if chkd.nil?
        return false
      else
        begin
          txt = chkd['details'].map { |e| e['output'] }
          return txt.map { |e| e.match?(self.regex) }.any?
        rescue Exception => e
          return false
        end
      end
    end
  end

  def report(email)
    rule = "package:%s - status:%s - flavor:%s - time:%s" %
      [self.package, self.status, self.flavor, self.time]
    out = {"email" => email, "package" => self.package,
      "rule" => rule, "time_found" => Time.now.utc.to_s}
    return out
  end
end

def recently_sent?(x)
  # list all keys
  keys = $redis.keys;
  # filter to only sidekiq-status redis keys (they are of Redis class hash)
  keys = keys.select { |e| e.match?('sidekiq:status') }
  if keys
    out = []
    keys.each do |z|
      tmp = $redis.hgetall(z)
      unless tmp.nil?
        tmp['args'] = MultiJson.load(tmp['args'])
        tmp['update_date'] = Time.at(tmp['update_time'].to_i).to_datetime
        unless tmp['args'].last.empty?
          tmp['crancheck_date'] = Date.parse().to_datetime
        end
        tmp["rules"] = tmp["args"][1..5]
        out << tmp
      end
    end

    roul = [x.package, x.status, x.flavor_original, x.time, x.regex]
    begin
      out.map { |e| e["rules"] == roul }.any?
    rescue Exception => e
      return false
    end
  else
    # no keys, return false (aka: not recently sent)
    return false
  end
end

def notify
  users = users_list();
  users.each do |x|
    rules = rules_find(email: x)
    next unless rules
    rules.each do |rule|
      doc = history_query({ name: rule["package"] });
      unless doc.nil?
        rl = CheckRule.new(rule, doc);
        recsent = recently_sent?(rl)
        if recsent
          Sidekiq::logger.info "rule " + ("[ %s ]" % rl.report(x)["rule"] || "[ unknown ]") + " was recently sent"
        end
        if rl.check and not recsent
          CchecksRuleReportEmail.perform_in(5.minutes, x, rl.package, rl.status, rl.flavor_original,
            rl.time, rl.regex, doc[:history][0]['date_updated'].to_s)
        end
      end
    end
  end
end
