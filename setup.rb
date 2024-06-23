require 'dotenv/load'
require 'tibber'
require 'growatt'


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

    @control = @client.inverter_control_data(@inverter_serial)
    if "0".eql? @control.exportLimit
      # disabled, full power
      @is_on = true
    else
      # export limit enabled, return percentage
      @is_on = false
    end
  end
  def is_on?
    @is_on
  end
  def turnon(on)
    if (@is_on != on)
      puts "Turning EV panels #{onoff(on)}"
      if on
        result = @client.export_limit(@inverter_serial,Growatt::ExportLimit::DISABLE)
      else
        result = @client.export_limit(@inverter_serial,Growatt::ExportLimit::PERCENTAGE, 100)
      end
      if result
        puts "EV panels are turned #{onoff(on)}"
        @is_on = on
      else
        puts "Error Turning EV panels #{onoff(on)}"
      end
    end
  end

  def onoff(on)
    on ? "on" : "off"
  end
end
