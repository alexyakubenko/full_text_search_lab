require 'sinatra'
require 'pg'
require 'haml'
require 'sass/plugin/rack'
require 'active_support/core_ext'

require './search.rb'

use Sass::Plugin::Rack

conn = PG.connect(:dbname => 'full_text_search', :user => 'postgres', :password => 'qwerty')
index = SearchIndex.new(conn)

get '/' do
  @count = conn.exec('SELECT COUNT(*) FROM documents;').first.values.first
  @documents = conn.exec('SELECT * FROM documents;')
  @index = index
  haml :index
end

get '/search' do
  @documents = index.search(params[:q])
  @words = index.words(params[:q])
  haml :response
end

get '/show/:id' do
  @text = conn.exec("SELECT text FROM documents WHERE id = #{ params[:id] };").first.try(:[], 'text')

  if @text.blank?
    redirect '/'
  else
    haml :show
  end
end

get '/delete/:id' do
  conn.exec("DELETE FROM documents WHERE id = #{ params[:id] };")
  index.rebuild!
  redirect '/'
end

post '/add' do
  if params[:text].present?
    conn.exec("INSERT INTO documents(text) VALUES ('#{ params[:text].gsub(/[\'|\"]/, '') }')")
    index.rebuild!
  end

  redirect '/'
end

get '/use_tf_idf' do
  index.rebuild!(true)
  redirect '/'
end

get '/use_bm_25' do
  index.rebuild!(false)
  redirect '/'
end