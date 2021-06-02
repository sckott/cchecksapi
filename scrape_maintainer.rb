require "faraday"
require 'typhoeus'
require 'typhoeus/adapters/faraday'
require "multi_json"
require "oga"
require "mongo"

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
$maint = $mongo[:maintainer]

def scrape_all_maintainers
  # maints = cran_maintainers;
  # resp_onses = async_get(maints);
  htmls = list_htmls("/tmp/mainthtmls/*");
  # out = Parallel.map(resp_onses, in_processes: 4) { |e| scrape_maintainer_body(e) };
  out = []
  htmls.each do |x|
    out << scrape_maintainer_body(x)
  end
  out.compact!
  if $maint.count > 0
    $maint.drop
    $maint = $mongo[:maintainer]
  end
  $maint.insert_many(out.map { |e| prep_mongo_(e) })
end

def prep_mongo_(x)
  x.merge!({'_id' => x["email"]})
  x.merge!({'date_updated' => DateTime.now.to_time.utc})
  return x
end

def scrape_maintainer_body(z)
  base_url = 'https://cloud.r-project.org/web/checks/check_results_%s.html'
  sub_str = "https-cloud-r-project-org-web-checks-check-results-"

  html = Oga.parse_html(File.read(z).force_encoding 'UTF-8')
  title = html.xpath('//title').text
  # if 404 not found return nil
  # - could be a maintainer of a package that's been archived and so no longer exists
  if !title.match(/404/).nil?
    return nil
  end
  if title.length == 0
    return {"email" => nil, "url" => nil, "table" => nil, "packages" => nil}
  end

  # fix here for a case where there's two instances of "Maintainer", e.g., 
  # "CRAN Package Check Results for Maintainer ‘Maintainer:  Wilson Lara <wilarhen at gmail.com>’"
  # https://cloud.r-project.org/web/checks/check_results_wilarhen_at_gmail.com.html
  str_prep = title.gsub(/\u00A0/, " ").split('Maintainer').reject {|x| x.strip.empty?}[1].sub(/:\s+/, "")
  email = str_prep.strip.split("<").last.sub(">", "").gsub(/[[:space:]]/, "_")
  maint_name = str_prep.strip.split("<")[0].gsub(/[[:space:]]$/, "")

  if html.xpath('//table').length == 0
    # no summary table
    tab = nil
  else
    # with summary table
    frow = html.xpath('//table//tr[contains(., "Package")]').text.split(" ")
    trs = html.xpath('//table//tr')

    out = []
    trs[1..-1].each do |x|
      tmp = x.xpath("td")
      pkg = tmp[0].text.strip
      out << [pkg, tmp[1..-1].map { |e| e.text.strip }].flatten
    end

    tab = out.map { |e| Hash[frow.zip(e)]  }
    tab.map { |a| a.keys.map { |k| a[k.downcase] = a.delete k } }
    tab.map { |a| a.map { |k, v| a[k] = v.to_i if k.match(/error|warn|note|ok/) } }
    # fill with missing keys
    fill_keys = {'error' => 0, 'warn' => 0, 'note' => 0, 'ok' => 0}
    tab.map { |a| a.merge! fill_keys.select { |k| !a.keys.include? k } }
    # add any key
    tab.map { |a| a["any"] = a.count_any != 0 }
    # sort keys
    keys_sorted = ['package', 'any', 'ok', 'note', 'warn', 'error']
    tab.map! { |a| keys_sorted.zip(a.values_at(*keys_sorted)).to_h }
  end

  # packages free text
  pkgs = html.xpath('//h3[contains(text(), "Package")]')
  dat = []
  pkgs.each do |x|
    pkg = x.attribute("id").text
    checks_url = 'https://cloud.r-project.org/web/checks/' + x.xpath("a").attribute("href")[0].value
    check = x.next.next.text.strip
    check = check.sub(/Current CRAN status:/, "").split(",").map { |e| e.split(":").map(&:strip) }
    check = check.map { |e| Hash[["category", "number_checks"].zip(e)] }
    check.map { |a| a.map { |k, v| a[k] = v.to_i if k.match(/number_checks/) } }
    #version = x.xpath("p").attribute("href")
    dat << {"package" => pkg, "url" => checks_url,
      "check_result" => check, "version" => nil}
  end

  return {"email" => email, "name" => maint_name, "url" => base_url % email,
    "table" => tab, "packages" => dat}
end

class Hash
  def count_any
    return self.slice('error', 'warn', 'note').values.sum
  end
end

# cran_maintainers()
def cran_maintainers
  conn = Faraday.new(:url => 'https://cloud.r-project.org/web/checks/check_summary_by_maintainer.html') do |f|
    f.adapter Faraday.default_adapter
  end
  x = conn.get
  html = Oga.parse_html(x.body)
  trs = html.xpath('//table//tr');
  strs = trs.map { |z| id = z.attribute("id"); id.text if !id.nil? }.compact
  strs = strs.map { |z| z.sub(/address:/, '') }
  return strs
end
