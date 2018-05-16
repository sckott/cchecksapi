require "multi_json"

$svg_colors = {
  "brightgreen" => "4c1",
  "green" => "97CA00",
  "yellowgreen" => "a4a61d",
  "yellow" => "dfb317",
  "orange" => "fe7d37",
  "red" => "e05d44",
  "lightgrey" => "9f9f9f",
  "blue" => "007ec6",
  "grey" => "D6D5D6"
}

$badge_svg = <<-eos
<svg xmlns="http://www.w3.org/2000/svg" width=":width:" height="20">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <mask id="a">
    <rect width=":width:" height="20" rx="3" fill="#fff"/>
  </mask>
  <g mask="url(#a)">
    <path fill="#555" d="M0 0h53v20H0z"/>
    <path fill=":color:" d="M53 0h:path_d:v20H53z"/>
    <path fill="url(#b)" d="M0 0h:width:v20H0z"/>
  </g>
  <g fill="#fff" text-anchor="middle"
     font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="26.5" y="15" fill="#010101" fill-opacity=".3">
      :text:
    </text>
    <text x="26.5" y="14">
      :text:
    </text>
    <text x=":textwidth:" y="15" fill="#010101" fill-opacity=".3">
      :message:
    </text>
    <text x=":textwidth:" y="14">
      :message:
    </text>
  </g>
</svg>
eos

def do_badge(package, params, body)
  pbody = MultiJson.load(body.to_json)
  if pbody.nil?
    message = "unknown"
  else
    if pbody["summary"]["any"].nil?
      message = "unknown"
    else
      message = pbody["summary"]["any"]
    end

    if !!message == message
      message = message ? "Not OK" : "OK"
    end
  end

  svg = make_badge("CChecks", message, params)
  return svg
end

def do_badge_flavor(package, flavor, body)
  pbody = MultiJson.load(body.to_json)
  if pbody.nil?
    message = "unknown"
  else
    res = pbody['checks'].select { |a| a["flavor"] == flavor }
    if res.length == 0
      message = "unknown"
    else
      message = res[0]["status"]
    end
  end

  svg = make_badge("CChecks", message, params)
  return svg
end

def make_badge(text, message, params)
  def_color = "brightgreen"
  def_color = "grey" if message == "unknown"
  def_color = "blue" if message.downcase == "note"
  def_color = "yellow" if message.downcase == "warn"
  def_color = "red" if message == "Not OK"
  def_color = "red" if message.downcase == "note"
  def_color = "red" if message.downcase == "error"
  color = params["color"] || def_color
  color = $svg_colors[color] || color

  len = message.length * 1.5
  if message == "unknown"
    width = 53 + 6 * len
    textwidth = 53 + 3 * len
    path_d = 36 + 6 * len
  else
    width = 71 + 6 * len - 3
    textwidth = 51 + 5 * len - 1.5
    path_d = 36 + 8 * len - 1.5
  end

  svg = $badge_svg.
    gsub(/:text:/, text).
    gsub(/:color:/, '#' + color.gsub(/[^\w]/, '')).
    gsub(/:width:/, width.to_s).
    gsub(/:textwidth:/, textwidth.to_s).
    gsub(/:path_d:/, path_d.to_s).
    gsub(/:message:/, message)

  return svg
end
