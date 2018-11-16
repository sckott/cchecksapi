require "mongo"
require 'date'

require_relative 'utils'

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

def scrape_history
  # get all pkgs from current set
  pkgs = hist_get_pkgs;
  
  # check if each pkg is in the historical set
  currnames = pkgs.map { |z| z['package']};
  histnames = history_pkg_names;
  to_add = currnames - histnames;
  if to_add.length > 0
    pkgsadd = pkgs.keep_if { |w| to_add.include? w['package'] };
  else
    pkgsadd = []
  end

  # add empties
  if pkgsadd.length > 0
    $cks_history.insert_many(pkgsadd.map { |e| { package: e['package'], history: [] } });
  end

  # add data
  # FIXME: this definitely could be faster, see if update_many will work
  pkgs.map { |e| history_update(e) };
  # $cks_history.update_many(pkgs.map { |e|  });
  
  # discard any data > 30 days since collected
  # FIXME: not quite sure how to do this
  thirtydaysago = Date.today - 30
  # { "package": "ambient", "data.$.date_updated" > thirtydaysago.to_time },
  $cks_history.update_many(
    { },
    { '$pull': { "history$date_updated": { '$lte': thirtydaysago.to_time.utc.to_s } } },
    { "multi": true }
  )
end

# zz = [{'package' => 'foo'}, {'package' => 'bar'}, {'package' => 'baz'}]
# $cks_history.insert_many(zz.map { |e| prep_history(e) })
def prep_history(x)
  x.merge!({'date' => []})
  return x
end

def history_update(x)
  $cks_history.update_one({ package: x['package'] },
    '$addToSet' => { history: x.slice('summary', 'checks', 'check_details', 'date_updated') })
end

def history_add_empty(x)
  $cks_history.insert_one({ package: x, history: [] })
end

def history_pkg_names
  tmp = $cks_history.find({}, {:fields => ["name"]});
  return tmp.to_a.map { |z| z['package']}
end

def hist_get_pkgs
  dat = $cks.find({}).to_a;
  return dat
end

def hist_has_pkg(x)
  z = $cks_history.find({ package: x }).limit(1).count
  return z > 0
end
