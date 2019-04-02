FROM ruby:2.6.0

MAINTAINER Scott Chamberlain <sckott@protonmail.com>

RUN JQ_URL="https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/jq-latest" \
  && curl --silent --show-error --location --fail --retry 3 --output /usr/bin/jq $JQ_URL \
  && chmod +x /usr/bin/jq \
  && jq --version

RUN GANDA_URL="https://github.com/tednaleid/ganda/releases/download/v0.1.6/ganda_0.1.6_linux_386.tar.gz" \
    && wget $GANDA_URL \
    && tar -zxvf ganda_0.1.6_linux_386.tar.gz \
    && mv ganda /usr/local/bin

COPY . /opt/sinatra
RUN cd /opt/sinatra \
  && bundle install
EXPOSE 8834

WORKDIR /opt/sinatra
CMD ["puma", "-C", "puma.rb"]
