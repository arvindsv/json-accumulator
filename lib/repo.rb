require 'json'
require 'securerandom'
require 'cgi'

class Repo
  DOCUMENTS_FILTER_NAME = 'only_documents'.freeze

  def initialize
    @couch_base_url = ENV['COUCH_BASE_URL'] || 'http://db:5984'
    @couchdb_username = ENV['COUCHDB_USERNAME'] || 'couch'
    @couchdb_password = ENV['COUCHDB_PASSWORD'] || 'password'
  end

  def initialize_db_for(db_name)
    uri = URI("#{@couch_base_url}/#{db_name}")
    return if document_exists?(uri)

    request_to_db = Net::HTTP::Put.new(uri)
    request_to_db.basic_auth @couchdb_username, @couchdb_password

    response_from_db = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request_to_db) }
    raise "Failed to initialize repo for: #{db_name} - Message: #{response_from_db.body}" unless response_from_db.is_a? Net::HTTPSuccess

    update_design_doc 'filter', db_name, DOCUMENTS_FILTER_NAME, "function(doc, req) { return doc.type === 'document'; }"
  end

  def latest_of(db_name)
    uri = URI("#{@couch_base_url}/#{db_name}/_changes?descending=true&limit=1&include_docs=true&filter=#{db_name}/#{DOCUMENTS_FILTER_NAME}")
    request_to_db = Net::HTTP::Get.new(uri)
    request_to_db.basic_auth @couchdb_username, @couchdb_password

    response_from_db = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request_to_db) }
    raise "Failed to get latest from: #{db_name} - Message: #{response_from_db.body}" unless response_from_db.is_a? Net::HTTPSuccess

    result_tweets = JSON.parse(response_from_db.body)['results']
    return {}.to_json if result_tweets.empty?
    result_tweets[0]['doc']['content'].to_json
  end

  def add_to(db_name, information_as_json)
    uri = URI("#{@couch_base_url}/#{db_name}/#{SecureRandom.uuid}")
    request_to_db = Net::HTTP::Put.new(uri)
    request_to_db.basic_auth @couchdb_username, @couchdb_password

    request_to_db.body = { type: 'document', content: information_as_json }.to_json
    response_from_db = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request_to_db) }

    raise "Failed to add to #{db_name}, information: #{information_as_json_string} - Message: #{response_from_db.body}" unless response_from_db.is_a? Net::HTTPSuccess
    [uri.to_s, response_from_db.body]
  end

  def update_design_doc(type_of_document, db_name, name, func)
    uri = URI("#{@couch_base_url}/#{db_name}/_design/#{db_name}")
    response_from_db = Net::HTTP.start(uri.hostname, uri.port) do |http|
      request_to_db = Net::HTTP::Get.new(uri)
      request_to_db.basic_auth @couchdb_username, @couchdb_password
      response_from_db = http.request(request_to_db)

      design_doc = { '_id' => "_design/#{db_name}", 'language' => 'javascript' }
      design_doc = JSON.parse(response_from_db.body) if response_from_db.is_a? Net::HTTPSuccess

      case type_of_document
      when 'filter'
        design_doc['filters'] ||= {}
        design_doc['filters'][name] = func
      when 'view'
        design_doc['views'] ||= {}
        design_doc['views'][name] ||= {}
        design_doc['views'][name]['map'] = func
      end

      request_to_db = Net::HTTP::Put.new(uri)
      request_to_db.basic_auth @couchdb_username, @couchdb_password
      request_to_db.body = design_doc.to_json
      response_from_db = http.request(request_to_db)
      raise "Failed to add #{type_of_document} #{name} to #{db_name} - Message: #{response_from_db.body} - Body sent was: #{request_to_db.body}" unless response_from_db.is_a? Net::HTTPSuccess
      response_from_db.body
    end
  end

  def find_using_view(db_name, view_name, key_to_search_for)
    uri = URI("#{@couch_base_url}/#{db_name}/_design/#{db_name}/_view/#{view_name}")
    uri.query = "key=#{CGI.escape(key_to_search_for)}" unless key_to_search_for.nil?
    request_to_db = Net::HTTP::Get.new(uri)
    request_to_db.basic_auth @couchdb_username, @couchdb_password

    response_from_db = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request_to_db) }
    raise "Failed to find using view #{view_name}: #{db_name} - Req: #{request_to_db} - Message: #{response_from_db.body}" unless response_from_db.is_a? Net::HTTPSuccess
    JSON.parse(response_from_db.body)['rows']
  end

  # Unique docs. There will be one of them. Ex: /db1/metadata, /db1/hello
  def get_unique_doc(db_name, id)
    uri = URI("#{@couch_base_url}/#{db_name}/#{id}")
    request_to_db = Net::HTTP::Get.new(uri)
    request_to_db.basic_auth @couchdb_username, @couchdb_password

    response_from_db = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request_to_db) }
    return [404, 'UNKNOWN', response_from_db] if response_from_db.is_a? Net::HTTPNotFound

    raise "Failed to get unique document with ID #{id} from: #{db_name} - Message: #{response_from_db.body}" unless response_from_db.is_a? Net::HTTPSuccess
    result = JSON.parse(response_from_db.body)
    [200, result['_rev'], result['content'].to_json]
  end

  def update_unique_doc(db_name, id, revision, information_as_json)
    uri = URI("#{@couch_base_url}/#{db_name}/#{id}")
    if document_exists?(uri)
      raise "Need revision when unique document already exists: #{id} in: #{db_name}" if revision.nil?
      uri.query = "rev=#{revision}"
    end

    request_to_db = Net::HTTP::Put.new(uri)
    request_to_db.basic_auth @couchdb_username, @couchdb_password

    request_to_db.body = { type: 'unique', content: information_as_json }.to_json
    response_from_db = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request_to_db) }

    raise "Failed to update unique document with ID #{id} from: #{db_name} with information: #{information_as_json} - Message: #{response_from_db.body}" unless response_from_db.is_a? Net::HTTPSuccess
    result = JSON.parse(response_from_db.body)
    [200, result['rev'], { status: 'created' }.to_json]
  end

  private

  def document_exists?(uri)
    fetch_document(uri).is_a? Net::HTTPSuccess
  end

  def fetch_document(uri)
    request_to_db = Net::HTTP::Get.new(uri)
    request_to_db.basic_auth @couchdb_username, @couchdb_password
    Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request_to_db) }
  end
end
