require_relative 'scrape'
require_relative 'scrape_maintainer'
require_relative 'history'

desc "load cran checks results into mongo"
task :loadmongo do
  begin
    scrape_all()
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

desc "update history"
task :loadhistory do
  begin
    history()
  rescue Exception => e
    raise e
  end
end

desc "cache history"
task :cachehistory do
  begin
    cache_history()
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
