require 'erb'
require 'sendgrid-ruby'
include SendGrid

# return sendgrid mail object
# email_prepare(to = "myrmecocystus@gmail.com", pkg="spocc", rule="bla bla")
# to = "myrmecocystus@gmail.com"
# pkg = 'wellknown'
# status = 'WARN'
# flavor = 'osx'
# time = nil
# regex = nil
# check_date_time = '2020-04-21 00:00 UTC'
def email_prepare(to:, pkg:, status:, flavor:, time:, regex:, check_date_time:)
  from = Email.new(email: 'sckott7@gmail.com', name: "CRAN Checks")
  to = Email.new(email: to)
  subject = "cranchecks report {%s}" % pkg
  template = ERB.new(File.read("email_template.erb"))
  html = template.result_with_hash({package: pkg, status: status, flavor: flavor, time: time, regex: regex,
    check_date_time: check_date_time})
  template_plain = ERB.new(File.read("email_template_plain.erb"))
  plain = template_plain.result_with_hash({package: pkg, status: status, flavor: flavor, time: time, regex: regex,
    check_date_time: check_date_time})
  content_plain = SendGrid::Content.new(type: 'text/plain', value: plain)
  content_html = Content.new(type: 'text/html', value: html)
  mail = Mail.new(from, subject, to, content_plain)
  mail.add_content(content_html)
  return mail
end

# send email, return email response object
# x: a Mail object from SendGrid, from email_prepare
def email_send(x)
  sg = SendGrid::API.new(api_key: ENV['SENDGRID_KEY'])
  response = sg.client.mail._('send').post(request_body: x.to_json)
  return response
end
