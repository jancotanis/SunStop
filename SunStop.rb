# frozen_string_literal: true

require 'optparse'
require './setup'

# Version number of the SunStop script
VERSION = '1.1'

##
# The Scheduler class handles retrieving electricity prices from Tibber
# and determining whether the Growatt inverter should be turned off.
class Scheduler
  attr_reader :client

  ##
  # Initializes the Scheduler with a Tibber client.
  #
  # @param client [Tibber::Client] The Tibber API client.
  def initialize(client)
    @client = client
  end

  ##
  # Fetches today's electricity prices from Tibber.
  #
  # @return [Array] An array of price data for the day.
  def todays_prices
    prices = client.price_info
    home = prices.homes.first
    home.currentSubscription.priceInfo.today
  end

  ##
  # Sleeps until the start of the next hour.
  def sleep_until_next_hour
    now = Time.now
    next_hour = Time.new(now.year, now.month, now.day, now.hour + 1)
    seconds_until_next_hour = (next_hour - now).to_i + 2

    puts "Sleeping until #{next_hour} for #{seconds_until_next_hour} seconds..."
    sleep seconds_until_next_hour
  end

  ##
  # Determines if the current electricity price is below a given threshold.
  #
  # @param price [Float] The cutoff price in the same currency as Tibber data.
  # @return [Boolean] `true` if the price is below the cutoff, `false` otherwise.
  def negative_prices?(price)
    price_info = current_price
    price_info.energy < price
  end

  ##
  # Retrieves the current electricity price.
  #
  # @return [Tibber::PriceInfo] The current electricity price data.
  def current_price
    Tools.current_price
  end
end

##
# Logs the inverter state and electricity price to a CSV file.
#
# @param price [Float] The current electricity price.
# @param onoff [String] "on" or "off", representing the inverter state.
def log(price, onoff)
  headers = File.exist?(CSV_LOG)
  ts = Time.now.strftime('%Y-%m-%d %H:%M')

  File.open(CSV_LOG, 'a') do |file|
    file.puts 'timestamp, price, state' unless headers
    file.puts "#{ts}, #{price}, #{onoff}"
  end
end

##
# Parses command-line options for SunStop.
#
# @return [Hash] Options parsed from the command line.
def parse_options
  options = { cutoff_price: 0.0, run: 1, limit: nil }

  OptionParser.new do |opts|
    opts.banner = 'Usage: SunStop.rb [options]'

    opts.on('-p', '--price PRICE', Float, 'Cutoff price in cents. Default is 0 cents.') do |price|
      options[:cutoff_price] = price.to_f / 100.0
      puts "Cutoff price set to #{options[:cutoff_price] * 100.0} cents"
    end

    opts.on('-l', '--limit WATTS', Float, 'Limit export to a max of WATTS watt when prices are negative. Default is 100% shutdown.') do |watts|
      options[:limit] = watts.to_i
      puts "Export limit set to #{options[:limit]}w"
    end

    opts.on('-r', '--run HOURS', Float, 'Run for the specified number of hours, checking once per hour.') do |hours|
      options[:run] = hours.to_i
    end

    opts.on_tail('-h', '-?', '--help', 'Show this message') do
      puts opts
      exit
    end
  end.parse!

  options
end

puts "SunStop #{VERSION} #{Time.now}"
options = parse_options

# Initialize scheduler and inverter
scheduler = Scheduler.new(Tibber.client)
ev = Inverter.new

puts ev.is_on? ? '- Inverter is on' : "- Inverter is limited (#{ev.control.exportLimitPowerRate}%)"

# Main loop for controlling the inverter
begin
  loop do
    current_price = scheduler.current_price
    puts "Prices are #{current_price.energy} #{current_price.currency}, cutoff at #{options[:cutoff_price]} #{current_price.currency}"

    result = false
    if scheduler.negative_prices?(options[:cutoff_price])
      result = ev.turnon(false, options[:limit]) if ev.is_on?
    else
      result = ev.turnon(true) unless ev.is_on?
    end

    log(current_price.energy, ev.onoff(ev.is_on?)) if result

    options[:run] -= 1
    options[:run] > 1 ? scheduler.sleep_until_next_hour : exit(0)
  end
rescue Interrupt
  puts "\r* Aborting SunStop"
end
