require 'sinatra'
require 'net/http'
require 'json'

set :bind, '0.0.0.0'

get "/latest" do
  uri = URI("http://localhost:5984/tweets/_changes?descending=true&limit=1&include_docs=true")
  req = Net::HTTP::Get.new(uri)
  req.basic_auth 'admin', 'password'

  response = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(req)}

  content_type :json
  status response.code

  return response.body unless response.kind_of? Net::HTTPSuccess

  result_tweets = JSON.parse(response.body)["results"]
  return {}.to_json if result_tweets.size == 0
  result_tweets[0]["doc"].to_json
end
