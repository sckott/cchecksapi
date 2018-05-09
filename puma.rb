workers 2
preload_app!
daemonize false
worker_timeout 30
directory File.join(File.dirname(__FILE__), '')
port 8834
