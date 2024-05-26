require 'dotenv/load'
require 'tibber'

Tibber.configure do |config|
  config.access_token = ENV['TIBBER_ACCESS_TOKEN']
  #config.logger = Logger.new(TEST_LOGGER)
end

client = Tibber.client
prices = client.price_info

home = prices.homes.first
today = home.currentSubscription.priceInfo.today
hour = today[Time.now.hour]
puts "Current price #{hour.startsAt} #{hour.total} #{hour.currency} (#{hour.energy} + #{hour.tax})"
if hour.energy < 0
  puts "Negative prices (netto #{hour.energy} #{hour.currency}), can stop invertor"
else
  puts "Positive prices (netto #{hour.energy} #{hour.currency})"
end
