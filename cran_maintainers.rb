#!/usr/bin/env ruby
require "faraday"
require "oga"
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

maints = cran_maintainers()
File.open("maintainers.txt", "w+") do |f|
  maints.each { |element| f.puts(element) }
end
puts "done"
