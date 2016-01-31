require 'sinatra'
require 'net/http'
require 'json'
require 'securerandom'

set :bind, '0.0.0.0'

class Repo
  BASE_URL = "http://localhost:5984"

  def initialize_db_for db_name
    return if db_exists? db_name

    uri = URI("#{BASE_URL}/#{db_name}")
    request_to_db = Net::HTTP::Put.new(uri)
    request_to_db.basic_auth 'admin', 'password'

    response_from_db = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request_to_db)}
    raise "Failed to initialize repo for: #{db_name} - Message: #{response_from_db.body}" unless response_from_db.kind_of? Net::HTTPSuccess
  end

  def latest_of db_name
    uri = URI("#{BASE_URL}/#{db_name}/_changes?descending=true&limit=1&include_docs=true")
    request_to_db = Net::HTTP::Get.new(uri)
    request_to_db.basic_auth 'admin', 'password'

    response_from_db = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request_to_db)}
    raise "Failed to get latest from: #{db_name} - Message: #{response_from_db.body}" unless response_from_db.kind_of? Net::HTTPSuccess

    result_tweets = JSON.parse(response_from_db.body)["results"]
    return {}.to_json if result_tweets.size == 0
    result_tweets[0]["doc"].to_json
  end

  def add_to db_name, information_as_json_string
    uri = URI("#{BASE_URL}/#{db_name}/#{SecureRandom.uuid}")
    request_to_db = Net::HTTP::Put.new(uri)
    request_to_db.basic_auth 'admin', 'password'

    request_to_db.body = information_as_json_string
    response_from_db = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request_to_db)}

    raise "Failed to add to #{db_name}, information: #{information_as_json_string} - Message: #{response_from_db.body}" unless response_from_db.kind_of? Net::HTTPSuccess
    [uri.to_s, response_from_db.body]
  end

  private
  def db_exists? db_name
    uri = URI("#{BASE_URL}/#{db_name}")
    request_to_db = Net::HTTP::Get.new(uri)
    request_to_db.basic_auth 'admin', 'password'

    response_from_db = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request_to_db)}
    response_from_db.kind_of? Net::HTTPSuccess
  end
end

CAPTURE_PATTERN_FOR_DB_NAME = '(\w+)'
repo = Repo.new

before do
  content_type :json
end

error do
  status 500
  JSON.pretty_generate({message: env['sinatra.error'].message})
end

not_found do
  JSON.pretty_generate({message: "Not found"})
end

get %r{/#{CAPTURE_PATTERN_FOR_DB_NAME}/latest} do |db_name|
  repo.initialize_db_for db_name
  repo.latest_of db_name
end

post %r{/#{CAPTURE_PATTERN_FOR_DB_NAME}} do |db_name|
  request.body.rewind
  info_to_save = request.body.read

  repo.initialize_db_for db_name
  uri, response = repo.add_to db_name, info_to_save

  headers "Location" => uri
  response
end