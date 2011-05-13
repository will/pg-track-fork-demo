require 'sinatra/base'
require 'json'
require './client'
require 'sequel'

class HPGDemo < Sinatra::Base
  set :public, File.dirname(__FILE__) + '/public'

  PROPERTIES = %w[state state_updated_at state_checked_at status plan created_at current_transaction forked_from tracking]
  get '/' do
    haml :index
  end

  get '/dbs' do
    JSON.dump dbs
  end

  get '/dbs/:name' do |name|
    url = ENV["HEROKU_POSTGRESQL_#{name.upcase}_URL"]
    halt(404) unless url

    db = HerokuPostgresql::Client10.new(url).get_database
    db = db.keep_if {|key| PROPERTIES.include? key.to_s }
    db[:rel] = db[:forked_from] ? "FORK" : db[:tracking] ? "TRACK" : nil
    db[:color] = get_color(url)
    JSON.dump db
  end

  def dbs
    ENV.keys.map do |k|
      k=~/^HEROKU_POSTGRESQL_(\w+)_URL$/
      $+
    end.compact
  end

  def get_color(url)
    color = 'white'
    begin
      db = Sequel.connect(url)
      color = db["select val from list where key='color'"].first[:val]
      db.disconnect
    rescue => e
      puts e.inspect
    end
    color
  end
end
