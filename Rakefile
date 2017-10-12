require_relative 'scrape'
require_relative 'scrape_maintainer'

desc "load cran checks results into mongo"
task :loadmongo do
  begin
    scrape_all()
    scrape_all_maintainers()
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
