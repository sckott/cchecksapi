require_relative 'scrape'
require_relative 'scrape_maintainer'
require_relative 'history'

# require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
  t.warning = false
end

desc 'Run tests'
task default: :test

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

desc "clean history"
task :cleanhistory do
  begin
    delete_history_older_than_30_days()
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
