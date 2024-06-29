require 'sinatra'
require 'csv'
require './setup'


set :port, 8080
set :bind, '0.0.0.0'

ev = Inverter.new

get '/' do
  'Hello, this is the status page!'
end

# Define a route for the status page
get '/status' do
  @files = Dir.glob("./*-cron.log")
  @price = Tools.current_price
  @inverter_on = ev.onoff(ev.is_on?)
  @inverter_prc = ev.control.exportLimitPowerRate
  csv_data = CSV.read("./sunstop.csv", headers: true)
  # Get the last 10 lines and reverse their order
  @logging = csv_data.each.to_a.last(10).reverse
  erb :'status/index'
end

# Start the server if this file is run directly
#run! if app_file == $0
