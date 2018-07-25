FROM ruby:2.5.0

MAINTAINER Scott Chamberlain <sckott@protonmail.com>

COPY . /opt/sinatra
RUN cd /opt/sinatra \
  && bundle install
EXPOSE 8834

WORKDIR /opt/sinatra
CMD ["puma", "-C", "puma.rb"]
