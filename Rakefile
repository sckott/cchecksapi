require_relative 'scrape'
require_relative 'scrape_history'
require_relative 'scrape_maintainer'

desc "load cran checks results into mongo"
task :loadmongo do
  begin
    scrape_all()
  rescue Exception => e
    raise e
  end
end

desc "put current day cran checks results into history db"
task :loadhistory do
  begin
    scrape_history()
  rescue Exception => e
    raise e
  end
end

desc "load cran maintainer summary checks into mongo"
task :loadmaints do
  begin
    scrape_all_maintainers()
  rescue Exception => e
    raise e
  end
end


desc "do one"
task :one do
  puts "one"
end

desc "do two"
task :two do
  puts "two"
end
