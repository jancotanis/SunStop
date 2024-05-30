require 'time'
require 'dotenv/load'
require 'logger'
require 'growatt'
require 'pvoutput/client'

TEST_LOGGER = 'growatt-history.log'
CONFIG = 'growatt-history.cfg'

def previous_month(now=Time.now)
  first_day_of_current_month = Time.new(now.year, now.month, 1)
  # Subtract one sec get the last day of the previous month
  last_day_of_previous_month = first_day_of_current_month - 1
  last_day_of_previous_month
end

def next_month(now=Time.now)
  # Calculate the next month and handle year transition
  if now.month == 12
    next_month_time = Time.new(now.year + 1, 1, 1)
  else
    next_month_time = Time.new(now.year, now.month + 1, 1)
  end
  next_month_time
end

def history(ev,inverter)
  # start time
  current_month = Time.new(2024, 5, 1)
  last_month = previous_month
  File.open("./pv-output.txt", 'w') do |file|
    while current_month <= last_month do
      yymm = current_month.strftime("%Y-%m")
      puts yymm
      data = ev.inverter_data(inverter.deviceSn,Growatt::Timespan::MONTH,current_month)

      data.attributes.keys.each do |day|
        file.puts "#{yymm}-#{day},#{data[day]}"
      end
      current_month = next_month(current_month)
    end
  end
end

def since_last_time(ev,pvout,inverter)
  now = Time.now
  if File.exist?(CONFIG)
    last_time = Time.parse(File.read(CONFIG))
  else
    last_time = Time.new(now.year,1,1)
  end
  puts "- last run: #{last_time}"
  current_month = last_time
  last_upload = current_month.strftime("%Y%m%d")
  while current_month <= now do
    yymm = current_month.strftime("%Y%m")
    puts "- loading period #{yymm}"
    data = ev.inverter_data(inverter.deviceSn,Growatt::Timespan::MONTH,current_month)

    output = {}
    data.attributes.keys.each do |day|
      date = "#{yymm}#{day.to_s.rjust(2,'0')}"
      if date >= last_upload
        kWh = data[day] * 1000
        output[date] = {:energy_generated => kWh}
      end
    end
    if output.keys.count > 0
      puts "- uploading batch #{yymm}, with #{output.keys.count} records"
      current_month = next_month(current_month)
    else
      puts "- nothing to upload"
    end
    current_month = next_month(current_month)
  end

  File.open(CONFIG, 'w') do |file|
    file.write(now)
  end
end

puts "GrowattHistory v1.0"

File.delete(TEST_LOGGER) if File.exist?(TEST_LOGGER)
Growatt.reset
Growatt.configure do |config|
  config.username = ENV['GROWATT_USERNAME']
  config.password = ENV['GROWATT_PASSWORD']
  config.logger = Logger.new(TEST_LOGGER)
end

ev = Growatt.client
ev.login

pvout = PVOutput::Client.new(ENV['PV_SYSTEM_ID'], ENV['PV_API_KEY'])

plants = ev.plant_list
plant_id = plants.data.first.plantId
devices = ev.device_list(plant_id)
inverter = devices.first

since_last_time(ev,pvout,inverter)
