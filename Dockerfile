FROM ruby:2.4.1

COPY . /opt/sinatra
RUN cd /opt/sinatra \
  && bundle install
EXPOSE 8834

WORKDIR /opt/sinatra
CMD ["unicorn", "-d", "-c", "unicorn.conf"]
