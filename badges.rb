require "multi_json"
require_relative "funs"

$flavors_os = {
  "linux" => [ 
    "r-devel-linux-x86_64-debian-clang",
    "r-devel-linux-x86_64-debian-gcc",
    "r-devel-linux-x86_64-fedora-clang",
    "r-devel-linux-x86_64-fedora-gcc",
    "r-patched-linux-x86_64",
    "r-release-linux-x86_64"
  ],
  "windows" => [
    "r-devel-windows-ix86+x86_64",
    "r-oldrel-windows-ix86+x86_64",
    "r-release-windows-ix86+x86_64"
  ],
  "solaris" => ["r-patched-solaris-x86"],
  "osx" => [
    "r-oldrel-osx-x86_64",
    "r-release-osx-x86_64"
  ]
}

$flavors_release = {
  "devel" => [
    "r-devel-linux-x86_64-debian-clang",
    "r-devel-linux-x86_64-debian-gcc",
    "r-devel-linux-x86_64-fedora-clang",
    "r-devel-linux-x86_64-fedora-gcc",
    "r-devel-windows-ix86+x86_64"
  ],
  "oldrel" => [
    "r-oldrel-osx-x86_64",
    "r-oldrel-windows-ix86+x86_64"
  ],
  "patched" => [
    "r-patched-linux-x86_64",
    "r-patched-solaris-x86"
  ],
  "release" => [
    "r-release-linux-x86_64",
    "r-release-osx-x86_64",
    "r-release-windows-ix86+x86_64"
  ]
}

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
    <path fill="#555" d="M0 0h43v20H0z"/>
    <path fill=":color:" d="M43 0h:path_d:v20H43z"/>
    <path fill="url(#b)" d="M0 0h:width:v20H0z"/>
  </g>
  <g fill="#fff" text-anchor="middle"
     font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="21.5" y="15" fill="#010101" fill-opacity=".3">
      :text:
    </text>
    <text x="21.5" y="14">
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
  ignore = as_bool(params[:ignore])
  pbody = MultiJson.load(body.to_json)
  if pbody.nil?
    message = "unknown"
  else
    if pbody["summary"].nil?
      message = "unknown"
    else
      if pbody["summary"]["any"].nil?
        message = "unknown"
      else
        if ignore
          xx = pbody["summary"]
          if !xx["any"]
            message = xx["any"]
          else
            if xx["warn"] == 0 && xx["error"] == 0
              message = false
            else
              message = xx["any"]
            end
          end
        else
          message = pbody["summary"]["any"]
        end
      end
    end

    if !!message == message
      message = message ? "Not OK" : "OK"
    end
  end

  svg = make_badge("CRAN", message, params)
  return svg
end

def do_badge_worst(package, params, body)
  pbody = MultiJson.load(body.to_json)
  if pbody.nil?
    message = "unknown"
  else
    if pbody["summary"].nil?
      message = "unknown"
    else
      if pbody["summary"]["any"].nil?
        message = "unknown"
      else
        xx = pbody["summary"]
        if xx["error"] > 0
          message = "ERROR"
        elsif xx["warn"] > 0
          message = "WARN"
        elsif xx["note"] > 0
          message = "NOTE"
        else
          message = "OK"
        end
      end
    end
  end

  svg = make_badge("CRAN", message, params)
  return svg
end

def do_badge_flavor(package, flavor, ignore, body)
  pbody = MultiJson.load(body.to_json)
  if pbody.nil?
    message = "unknown"
  else
    if pbody["checks"].nil?
      message = "unknown"
    else
      res = pbody['checks'].select { |a| a["flavor"].include? flavor }
      if res.length == 0
        message = "unknown"
      else
        stats = res.map {|a| a['status']}
        if ignore
          message = ['ERROR', 'WARN'].map { |a| stats.include? a }.any? ? "Not OK" : "OK"
        else
          message = stats.all? { |w| w == "OK" } ? "OK" : "Not OK"
        end
      end
    end
  end

  svg = make_badge("CRAN", message, params)
  return svg
end

def make_badge(text, message, params)
  def_color = "brightgreen"
  def_color = "grey" if message.to_s == "unknown"
  def_color = "blue" if message.to_s.downcase == "note"
  def_color = "yellow" if message.to_s.downcase == "warn"
  def_color = "red" if message.to_s == "Not OK"
  def_color = "red" if message.to_s.downcase == "error"
  color = params["color"] || def_color
  color = $svg_colors[color] || color

  len = message.length
  if message == "unknown"
    width = 53 + 6 * len
    textwidth = 47 + 3 * len
    path_d = 36 + 6 * len
  else
    width = 61 + 6 * len - 3
    textwidth = 51 + 3 * len - 1.5
    path_d = 36 + 6 * len - 1.5
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
