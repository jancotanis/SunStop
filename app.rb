require 'sinatra'
require 'csv'
require './setup'

LAST_LOG = './sunstop-cron.log'

set :port, 8080
set :bind, '0.0.0.0'

ev = Inverter.new

get '/' do
  'Hello, this is the status page!'
end

# Define a route for the status page
get '/status' do
  @last_run = ''
  @last_run = File.read(LAST_LOG) if File.exist?(LAST_LOG)
  @prices = Tools.prices
  @price = Tools.current_price
  if File.exist?(CSV_LOG)
    csv_data = CSV.read("./sunstop.csv", headers: true, strip: true)
    @logging = csv_data.each.to_a.last(10).reverse
  else
    @logging = []
  end
  @inverter_on = 'error'
  @inverter_prc = 'error'
  begin
    @inverter_on = ev.onoff(ev.read_state)
    @inverter_prc = ev.control.exportLimitPowerRate
  rescue
  end
  # Get the last 10 lines and reverse their order
  erb :'status/index'
end

# Start the server if this file is run directly
#run! if app_file == $0
