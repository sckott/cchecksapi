require "faraday"
require "multi_json"
require "oga"
require "mongo"

$mongo = Mongo::Client.new([ ENV.fetch('MONGO_PORT_27017_TCP_ADDR') + ":" + ENV.fetch('MONGO_PORT_27017_TCP_PORT') ], :database => 'cchecksdb')
#$mongo = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'cchecksdb')
$maint = $mongo[:maintainer]

def scrape_all_maintainers
  maints = cran_maintainers;
  out = []
  maints.each do |x|
    out << scrape_maintainer(x)
  end
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

# scrape_maintainer(email = "a.barnett_at_qut.edu.au") # exists
# scrape_maintainer(email = "aba44_at_pitt.edu") # exists
# scrape_maintainer(email = "things_at_stuff.com") # doesn't exist
def scrape_maintainer(email)
  base_url = 'https://cran.rstudio.com/web/checks/check_results_%s.html'
  x = Faraday.new(:url => base_url % email) do |f|
    f.adapter Faraday.default_adapter
  end
  res = x.get;
  if !res.success?
    return {"email" => email, "url" => nil, "table" => nil, "packages" => nil}
  end

  html = Oga.parse_html(res.body.force_encoding 'UTF-8')
  title = html.xpath('//title').text
  maint_name = title.split('Maintainer')[1].strip.split("<")[0].gsub(/[[:space:]]$/, "")

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
  end

  # packages free text
  pkgs = html.xpath('//h3[contains(text(), "Package")]')
  dat = []
  pkgs.each do |x|
    pkg = x.attribute("id").text
    checks_url = 'https://cran.rstudio.com/web/checks/' + x.xpath("a").attribute("href")[0].value
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

# cran_maintainers()
def cran_maintainers
  conn = Faraday.new(:url => 'https://cran.rstudio.com/web/checks/check_summary_by_maintainer.html') do |f|
    f.adapter Faraday.default_adapter
  end
  x = conn.get
  html = Oga.parse_html(x.body)
  trs = html.xpath('//table//tr');
  strs = trs.map { |z| id = z.attribute("id"); id.text if !id.nil? }.compact
  strs = strs.map { |z| z.sub(/address:/, '') }
  return strs
end
