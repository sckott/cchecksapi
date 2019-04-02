require "faraday"
require 'typhoeus'
require 'typhoeus/adapters/faraday'

def async_get(x)
  conn = Faraday.new(:url => "https://cloud.r-project.org") do |faraday|
    faraday.adapter :typhoeus
  end

  urlx = x.map {|z| '/web/checks/check_results_%s.html' % z};
  reqs = []
  urlx.each_slice(100) do |urlchunk|
    responses = []
    conn.in_parallel do
      urlchunk.each do |z|
        responses << conn.get(z)
      end
    end

    reqs << responses.keep_if { |r| r.status == 200 }
  end
  # return array of Faraday::Response objects
  return reqs.flatten 
end

def list_htmls(path)
  files = Dir[path];
  return files
end
