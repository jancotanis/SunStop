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
    #@is_on = @client.inverter_on?(@inverter_serial)
    control = @client.inverter_control_data(@inverter_serial)
    if "0".eql? control.exportLimit
      # disabled, full power
      @is_on = true
      puts "- Inverter is on"
    else
      # export limit enabled, return percentage
      puts "- Inverter is limited (#{control.exportLimitPowerRate}%)"
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


puts "SunStop #{VERSION} #{Time.now}"
puts " Stops Growatt-inverter output if energy prices are subzero."
puts " Use SunStop [n=1]"
puts " - n is number of times to run, default is once; checks once each hour."

Tibber.configure do |config|
  config.access_token = ENV['TIBBER_ACCESS_TOKEN']
end

scheduler = Scheduler.new(Tibber.client)
ev = Inverter.new

if ARGV[0]
  count = ARGV[0].to_i
else
  count = 1
end

puts "- Looping #{count} time(s)\n"

begin
  loop do
    puts "Prices are #{scheduler.current_price.energy} #{scheduler.current_price.currency}"
    if scheduler.negative_prices?
      ev.turnon(false) if ev.is_on?
    else
      ev.turnon(true) unless ev.is_on?
    end
    count = count - 1
    if count > 1
      scheduler.sleep_until_next_hour
    else
      exit 0
    end
  end
rescue Interrupt
  puts "\r* Aborting SunStop"
end
