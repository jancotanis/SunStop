require 'dotenv/load'
require 'tibber'
require 'growatt'

VERSION = "1.0"

class Scheduler
  attr_reader :client

  def initialize(client)
    @client = client
  end

  def todays_prices
    prices = client.price_info
    home = prices.homes.first
    today = home.currentSubscription.priceInfo.today
  end

  def sleep_until_next_hour
    # Get the current time
    now = Time.now

    # Calculate the time of the next hour
    next_hour = Time.new(now.year, now.month, now.day, now.hour + 1)

    # Calculate the number of seconds until the next hour
    seconds_until_next_hour = (next_hour - now).to_i + 2

    puts "Sleeping until #{next_hour} for #{seconds_until_next_hour} seconds..."

    # Sleep for that duration
    sleep seconds_until_next_hour
  end

  # do we have negative prices at this moment?
  def negative_prices?
    price_info = current_price
    price_info.energy < 0
  end

  def current_price
    todays_prices[Time.now.hour]
  end
end

class Inverter
  def initialize
    Growatt.configure do |config|
      config.username = ENV['GROWATT_USERNAME']
      config.password = ENV['GROWATT_PASSWORD']
    end

    @client = Growatt.client
    @client.login
    @inverter_serial = @client.inverter_list(@client.login_info['data'].first['plantId']).first.deviceSn
    @is_on = @client.inverter_on?(@inverter_serial)
  end
  def is_on?
    @is_on
  end
  def turnon(on)
    if (@is_on != on)
      puts "Turning EV panels #{onoff(on)}"
      if @client.turn_inverter(@inverter_serial,on)
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


Tibber.configure do |config|
  config.access_token = ENV['TIBBER_ACCESS_TOKEN']
end

scheduler = Scheduler.new(Tibber.client)
ev = Inverter.new

puts "SunStop #{VERSION}"
# endless loop
loop do
  if scheduler.negative_prices?
    puts "Stop EV panels, prices are #{scheduler.current_price.energy} #{scheduler.current_price.currency}"
    ev.turnon(false) if ev.is_on?
  else
    puts "Start EV panels, prices are #{scheduler.current_price.energy} #{scheduler.current_price.currency}"
    ev.turnon(true) unless ev.is_on?
  end
  scheduler.sleep_until_next_hour
end
