# frozen_string_literal: true

require 'dotenv/load'
require 'tibber'
require 'growatt'

# Path to the CSV log file for storing sunstop data
CSV_LOG = './sunstop.csv'

# Configure Tibber API access using environment variables.
Tibber.configure do |config|
  config.access_token = ENV['TIBBER_ACCESS_TOKEN']
end

# Configure Growatt API access using environment variables.
Growatt.configure do |config|
  config.username = ENV['GROWATT_USERNAME']
  config.password = ENV['GROWATT_PASSWORD']
end

# Provides utility functions related to Tibber price data.
class Tools
  @@prices = {}
  def self.prices
    cache_id = Time.now.strftime '%Y-%m-%d-%H'
    # Retrieve cached price or fetch new price from Tibber
    prices = @@prices[cache_id] || Tibber.client.price_info.homes.first.currentSubscription.priceInfo.today
    @@prices = {cache_id => prices}  # Update cache
    prices
  end

  # Retrieves the current electricity price from Tibber.
  # Prices are cached for one hour to minimize API calls.
  #
  # @return [Float] The current electricity price.
  #
  # @example Get the current price
  #   Tools.current_price  # => 0.15 (example price)
  def self.current_price
    prices[Time.now.hour]
  end
end

# Manages interactions with a Growatt inverter.
class Inverter
  attr_reader :control  # Stores inverter control data

  # Initializes the Inverter instance and logs into Growatt.
  def initialize
    @client = Growatt.client
    @client.login
    @inverter_serial = @client.inverter_list(@client.login_info['data'].first['plantId']).first.deviceSn
    read_state
  end

  # Checks if the inverter is currently turned on.
  #
  # @return [Boolean] `true` if the inverter is on, `false` otherwise.
  #
  # @example Check if inverter is on
  #   inverter = Inverter.new
  #   inverter.is_on?  # => true
  def is_on?
    @is_on
  end

  # Reads the current state of the inverter and updates `@is_on`.
  #
  # @return [Boolean] The updated state of the inverter.
  def read_state
    @control = @client.inverter_control_data(@inverter_serial)
    if "0".eql? @control.exportLimit
      # Disabled, full power mode
      @is_on = true
    else
      # Export limit enabled
      @is_on = false
    end
    @is_on
  end

  # Turns the inverter on or off with an optional power limit.
  #
  # @param on [Boolean] `true` to turn on, `false` to turn off.
  # @param limit [Integer, nil] Power limit in watts when turning off (optional).
  # @return [Boolean] `true` if the operation was successful, `false` otherwise.
  #
  # @example Turn on the inverter
  #   inverter.turnon(true)
  #
  # @example Turn off the inverter with a power limit
  #   inverter.turnon(false, 500)
  def turnon(on, limit = nil)
    result = false
    if (@is_on != on)
      puts "Turning EV panels #{onoff(on)}"
      if on
        result = @client.export_limit(@inverter_serial, Growatt::ExportLimit::DISABLE)
      else
        result = if limit
          @client.export_limit(@inverter_serial, Growatt::ExportLimit::WATT, limit)
        else
          @client.export_limit(@inverter_serial, Growatt::ExportLimit::PERCENTAGE, 100)
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

  private

  # Converts a boolean state to "on" or "off" string.
  #
  # @param on [Boolean] `true` for "on", `false` for "off".
  # @return [String] "on" or "off".
  def onoff(on)
    on ? "on" : "off"
  end
end
