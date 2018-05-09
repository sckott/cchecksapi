FROM ruby:2.4.1

COPY . /opt/sinatra
RUN cd /opt/sinatra \
  && bundle install
EXPOSE 8834

WORKDIR /opt/sinatra
CMD ["puma", "-d", "-C", "puma.rb"]
