require './setup'

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
    Tools.current_price
  end
end



puts "SunStop #{VERSION} #{Time.now}"
puts "Stops Growatt-inverter output if energy prices are subzero."


scheduler = Scheduler.new(Tibber.client)
ev = Inverter.new
if ev.is_on?
  puts "- Inverter is on"
else
  puts "- Inverter is limited (#{ev.control.exportLimitPowerRate}%)"
end
if ARGV[0]
  count = ARGV[0].to_i
else
  count = 1
end

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
