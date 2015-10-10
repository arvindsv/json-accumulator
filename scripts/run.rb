require 'sinatra'
require 'net/http'
require 'json'
require 'securerandom'

set :bind, '0.0.0.0'

get "/tweets/latest" do
  uri = URI("http://localhost:5984/tweets/_changes?descending=true&limit=1&include_docs=true")
  req = Net::HTTP::Get.new(uri)
  req.basic_auth 'admin', 'password'

  response_from_db = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(req)}

  content_type :json
  status response_from_db.code

  return response_from_db.body unless response_from_db.kind_of? Net::HTTPSuccess

  result_tweets = JSON.parse(response_from_db.body)["results"]
  return {}.to_json if result_tweets.size == 0
  result_tweets[0]["doc"].to_json
end

post "/tweet" do
  request.body.rewind
  info_to_save = request.body.read

  uri = URI("http://localhost:5984/tweets/#{SecureRandom.uuid}")
  request_to_db = Net::HTTP::Put.new(uri)
  request_to_db.basic_auth 'admin', 'password'

  request_to_db.body = info_to_save
  response_from_db = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request_to_db)}

  content_type :json
  status response_from_db.code

  return response_from_db.body unless response_from_db.kind_of? Net::HTTPSuccess

  headers "Location" => uri.to_s
  response_from_db.body
end
