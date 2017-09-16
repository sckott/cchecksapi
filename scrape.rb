require "faraday"
require "multi_json"
require "oga"
require "couchrest"

server = CouchRest.new
$cdb = server.database!('cchecksdb')

def scrape_all
  pkgs = ro_packages;
  out = []
  pkgs.each do |x|
    out << scrape_pkg(x)
  end
  out.map { |e| store_db(e) };
end

def store_db(x)
  x.merge!({'_id' => x["package"]})
  x.merge!({'date_created' => DateTime.now.to_time.utc})
  $cdb.save_doc(x)
end

# scrape_pkg(pkg = "lawn") # exists
# scrape_pkg(pkg = "alm") # doesn't exist
def scrape_pkg(pkg)
  base_url = 'https://cran.rstudio.com/web/checks/check_results_%s.html'
  x = Faraday.new(:url => base_url % pkg) do |f|
    f.adapter Faraday.default_adapter
  end
  res = x.get
  if !res.success?
    return {"package" => pkg, "checks" => nil}
  end

  html = Oga.parse_html(res.body)
  tr = html.xpath('//table//tr');
  rws = tr.map { |e| e.xpath('./td//text()').map { |w| w.text }  }.keep_if { |a| a.length > 0 }
  rws = rws.map { |e| e.map { |f| f.lstrip } }
  rws = rws.map { |e| [e[2], e[3], e[4], e[5], e[6], e[9]] }
  nms = tr[0].text.split(' ')
  nms.pop
  res = rws.map { |e| Hash[nms.zip(e)] }

  # get urls and join to dataset
  hrefs = fetch_urls(tr)
  hrefs.each_with_index do |val, i|
    res[i].merge!({"check_url" => hrefs[i]})
  end

  return {"package" => pkg, "checks" => res}
end

def fetch_urls(foo)
  tmp = foo.map { |e| e.xpath('./td//a[contains(.//span, "OK") or contains(.//span, "ERROR")]') }
  tmp = tmp.keep_if { |e| e.length > 0 }
  xx = tmp.map { |e| e.attribute('href')[0].text }
  return xx
end

# ro_packages()
def ro_packages
  conn = Faraday.new(:url => 'https://raw.githubusercontent.com/ropensci/roregistry/master/registry.json') do |f|
    f.adapter Faraday.default_adapter
  end
  x = conn.get
  out = MultiJson.load(x.body)
  pkgs = out['packages'].collect { |x| x['name'] }
  return pkgs
end
