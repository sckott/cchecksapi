FROM ruby:2.4.1

MAINTAINER Scott Chamberlain <sckott@protonmail.com>

COPY . /opt/sinatra
RUN cd /opt/sinatra \
  && bundle install
EXPOSE 8834

WORKDIR /opt/sinatra
CMD ["puma", "-C", "puma.rb"]
