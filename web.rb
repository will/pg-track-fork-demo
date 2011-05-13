require 'sinatra/base'
require 'json'
require './client'
require 'sequel'

class HPGDemo < Sinatra::Base
  set :public, File.dirname(__FILE__) + '/public'

  PROPERTIES = %w[state state_updated_at state_checked_at status plan created_at current_transaction forked_from tracking elastic_ip]
  get '/' do
    haml :index
  end

  get '/dbs' do
    return fake['dbs'] if ENV['FAKE']
    JSON.dump dbs
  end

  get '/dbs/:name' do |name|
    return fake[name] if ENV['FAKE']

    url = ENV["HEROKU_POSTGRESQL_#{name.upcase}_URL"]
    halt(404) unless url

    db = HerokuPostgresql::Client10.new(url).get_database
    db = db.keep_if {|key| PROPERTIES.include? key.to_s }
    db[:rel] = db[:forked_from] ? "FORK" : db[:tracking] ? "TRACK" : nil
    db[:color] = get_color(url) unless ['waiting', 'create'].include? db[:state]

    JSON.dump db
  end

  post '/dbs/:name' do |name|
    url = ENV["HEROKU_POSTGRESQL_#{name.upcase}_URL"]
    set_color(url, params['color'])
  end

  def dbs
    ENV.keys.map do |k|
      k=~/^HEROKU_POSTGRESQL_(\w+)_URL$/
      $+
    end.compact
  end

  def set_color(url,color)
    begin
      db = Sequel.connect(url)
      db["update list set val='#{color}' where key='color'"].first
      db.disconnect
    rescue => e
      puts e.inspect
    end
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

  def fake
    {
      'BLUE' => %q({"state":"standby","state_updated_at":"2011-05-13 13:48:22 -0700","state_checked_at":"2011-05-13 13:52:55 -0700","status":"[16KB:1T:2C], (v9.0.4)","elastic_ip":"5.1.1.2","plan":"ronin","created_at":"2011-05-13 13:40:15 -0700","tracking":"yes","current_transaction":739,"rel":"TRACK","color":"cadetblue"}),
      'ORANGE' => %q({"state":"available","state_updated_at":"2011-05-12 23:41:06 -0700","state_checked_at":"2011-05-13 13:54:18 -0700","status":"[16KB:1T:4C], (v9.0.4)","elastic_ip":"5.1.9.6","plan":"ronin","created_at":"2011-05-12 23:35:41 -0700","current_transaction":739,"rel":null,"color":"cadetblue"}),
      'dbs' => '["ORANGE", "BLUE"]'
    }
  end
end
