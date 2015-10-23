require 'uri'
require 'json'
require 'net/http/persistent'

module Utils
private
  def make_http
    http = Net::HTTP::Persistent.new
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http
  end

  def make_uri(config, path)
    url = "https://#{config['company']}.supportbee.com#{path}"
    if path.include?("?")
      url << "&auth_token=#{config['auth_token']}"
    else
      url << "?auth_token=#{config['auth_token']}"
    end
    URI.parse(url)
  end

  def get_http_json(config, http, path)
    uri = make_uri(config, path)
    auth_token = config['auth_token']
    puts " --> GET #{uri.to_s.gsub(auth_token, '***')}"
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    response = http.request(uri, request)
    if response.code == '200'
      puts "     Response: 200"
      JSON.parse(response.body)
    else
      STDERR.puts "    Response: #{response.code}\n     Body:\n#{response.body}"
    end
  end
end
