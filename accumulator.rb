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
