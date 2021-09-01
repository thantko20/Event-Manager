require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  number = number.delete("^0-9").to_s
  length = number.length

  if length == 10
    format_number(number)
  elsif length == 11 && number[0] == '1'
    number.slice!(0)
    format_number(number)
  else
    "invalid number"
  end
end

def format_number(number)
  [3, 7].each { |i| number.insert(i, '-')}
  number
end

def get_hour(time)
  time = Time.strptime(time, '%m/%d/%y %H:%M')
  time.hour.to_s
end

def store_targets(hash, key)
  hash[key] = 0 unless hash[key]
  hash[key] += 1
end

def sort_hash(hash)
  hash.sort_by {|k, v| -v}.to_h
end

=begin
def save_peak_hours(hash, name)
  filename = "#{name}.txt"

  File.open(filename, 'w') do |file|
    hash.each do |k, v|
      file.puts "At hour #{k} of the day, #{v} person(s) registered."
    end
  end
end
=end

def get_day(time)
  day = Date.strptime(time, '%m/%d/%y %H:%M')
  convert_day(day.wday)
end

def convert_day(day)
  case day
  when 0
    'Sunday'
  when 1
    'Monday'
  when 2
    'Tuesday'
  when 3
    'Wednesday'
  when 4
    'Thursday'
  when 5
    'Friday'
  when 6
    'Saturday'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def save_targets(targets)
  Dir.mkdir('targets') unless Dir.exist?('targets')

  filename = 'targets/target.html'

  File.open(filename, 'w') do |file|
    file.puts targets
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true, 
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hour_hash = Hash.new
day_hash = Hash.new
template_target = File.read('target.erb')
erb_target = ERB.new template_target

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  number = clean_phone_number(row[:homephone])
  hour = get_hour(row[:regdate])
  day = get_day(row[:regdate])
  legislators = legislators_by_zipcode(zipcode)

  store_targets(hour_hash, hour)
  store_targets(day_hash, day)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

hour_hash = sort_hash(hour_hash)
day_hash = sort_hash(day_hash)
target = erb_target.result(binding)
save_targets(target)