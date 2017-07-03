#!/usr/bin/env ruby

require_relative 'lib/repo.rb'
require 'sinatra'
require 'net/http'
require 'json'

set :bind, '0.0.0.0'

repo = Repo.new

before do
  content_type :json
end

error do
  status 500
  JSON.pretty_generate(message: env['sinatra.error'].message)
end

not_found do
  JSON.pretty_generate(message: 'Route not found')
end

get '/:db_name/latest' do |db_name|
  repo.initialize_db_for db_name
  repo.latest_of db_name
end

post '/:db_name/view/:view_name' do |db_name, view_name|
  request.body.rewind
  view_function_body = request.body.read

  repo.initialize_db_for db_name
  repo.update_design_doc 'view', db_name, view_name, view_function_body
end

get '/:db_name/view/:view_name' do |db_name, view_name|
  key = params[:key]

  repo.initialize_db_for db_name
  repo.find_using_view(db_name, view_name, key).to_json
end

post '/:db_name' do |db_name|
  request.body.rewind
  info_to_save = JSON.parse(request.body.read)

  repo.initialize_db_for db_name
  uri, response = repo.add_to db_name, info_to_save

  headers 'Location' => uri
  response
end

get '/:db_name/doc/:unique_doc_id' do |db_name, unique_doc_id|
  repo.initialize_db_for db_name
  response_status, revision, response_body = repo.get_unique_doc db_name, unique_doc_id

  status response_status
  etag revision
  response_body
end

put '/:db_name/doc/:unique_doc_id/?:revision?' do |db_name, unique_doc_id, revision|
  request.body.rewind
  info_to_save = JSON.parse(request.body.read)

  repo.initialize_db_for db_name
  response_status, revision, response_body = repo.update_unique_doc db_name, unique_doc_id, revision, info_to_save

  status response_status
  etag revision
  response_body
end
