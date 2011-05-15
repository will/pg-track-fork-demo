require 'sinatra/base'
require 'json'
require './client'
require 'sequel'

class HPGDemo < Sinatra::Base
  set :public, File.dirname(__FILE__) + '/public'

  get '/' do
    haml :index
  end

  PROPERTIES = %w[state status current_transaction forked_from tracking elastic_ip]
  get '/dbs' do
    return fake['dbs'] if ENV['FAKE']

    dbs = ENV.keys.map do |k|
      k=~/^HEROKU_POSTGRESQL_(\w+)_URL$/
      $+
    end.compact.map do |db|
      hpg = HerokuPostgresql::Client10.new( url_from_name(db) ).get_database
      hpg.keep_if {|key| PROPERTIES.include? key.to_s}
      hpg[:rel] = hpg[:forked_from] ? "FORK" : hpg[:tracking] ? "TRACK" : "HEAD"
      [db, hpg]
    end

    JSON.dump Hash[dbs]
  end

  get '/dbs/:name' do |name|
    return fake[name] if ENV['FAKE']
    url = ENV["HEROKU_POSTGRESQL_#{name.upcase}_URL"]
    halt(404) unless url
    db = {}
    db[:colors] = get_color(url)

    JSON.dump db
  end

  post '/dbs/:name' do |name|
    color = params['color']
    set_color(url_from_name(name), color) unless color.empty?
  end

  def url_from_name(name)
    ENV["HEROKU_POSTGRESQL_#{name.upcase}_URL"]
  end

  def set_color(url,color)
    begin
      db = Sequel.connect(url)
      db[:colors].insert :color => color
      db.disconnect
    rescue => e
      puts e.inspect
    end
  end

  def get_color(url)
    colors = ['crimson']
    begin
      db = Sequel.connect(url)
      colors = db[:colors].limit(8).order_by(:id.desc).all.map{|r| r[:color]}.compact
      db.disconnect
    rescue => e
      puts e.inspect
    end
    colors
  end

  def fake
    {
      'BLUE' =>   %q({"colors":["cadetblue","orange","red","cadetblue","gold","crimson","orange","red"]}),
      'ORANGE' => %q({"colors":["cadetblue","orange","red","cadetblue","gold","crimson","orange","red"]}),
      'dbs' => %q({"BLUE":{"state":"standby","status":"[40KB:1T:2C], (v9.0.4)","elastic_ip":"5.1.1.2","tracking":"resource762@heroku.com","current_transaction":776,"rel":"TRACK"},"ORANGE":{"state":"available","status":"[48KB:1T:1C], (v9.0.4)","elastic_ip":"5.1.5.6","current_transaction":776,"rel":"HEAD"}})
    }
  end
end
