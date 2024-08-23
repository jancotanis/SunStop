require 'dotenv/load'
require 'tibber'
require 'growatt'

CSV_LOG = './sunstop.csv'

Tibber.configure do |config|
  config.access_token = ENV['TIBBER_ACCESS_TOKEN']
end

Growatt.configure do |config|
  config.username = ENV['GROWATT_USERNAME']
  config.password = ENV['GROWATT_PASSWORD']
end

class Tools
  @@prices = {}
  def self.current_price
    cache_id = Time.now.strftime '%Y-%m-%d-%H'
    # cache for an hour
    prices = @@prices[cache_id] || Tibber.client.price_info.homes.first.currentSubscription.priceInfo.today
    @@prices = {cache_id => prices}
    prices[Time.now.hour]
  end
end

class Inverter
attr_reader :control
  def initialize
    @client = Growatt.client
    @client.login
    @inverter_serial = @client.inverter_list(@client.login_info['data'].first['plantId']).first.deviceSn
    read_state
  end

  def is_on?
    @is_on
  end

  def read_state
    @control = @client.inverter_control_data(@inverter_serial)
    if "0".eql? @control.exportLimit
      # disabled, full power
      @is_on = true
    else
      # export limit enabled, return percentage
      @is_on = false
    end
    @is_on
  end

  def turnon(on, limit=nil)
    result = false
    if (@is_on != on)
      puts "Turning EV panels #{onoff(on)}"
      if on
        result = @client.export_limit(@inverter_serial,Growatt::ExportLimit::DISABLE)
      else
        if limit
          result = @client.export_limit(@inverter_serial,Growatt::ExportLimit::WATT, limit)
        else
          result = @client.export_limit(@inverter_serial,Growatt::ExportLimit::PERCENTAGE, 100)
        end
      end
      if result
        puts "EV panels are turned #{onoff(on)}"
        @is_on = on
      else
        puts "Error Turning EV panels #{onoff(on)}"
      end
    end
    result
  end

  def onoff(on)
    on ? "on" : "off"
  end
end
