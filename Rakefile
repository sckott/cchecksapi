require_relative 'scrape'

desc "load cran checks results into mongo"
task :loadmongo do
  begin
    scrape_all()
  rescue Exception => e
    raise e
  end
end
