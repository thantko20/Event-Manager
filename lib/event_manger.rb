require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
#require 'pry-byebug'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

# Create method for clean phone numbers
# i.e, If the phone number is less than 10 digits, assume that it is a bad number
# If the phone number is 10 digits, assume that it is good
# If the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10 digits
# If the phone number is 11 digits and the first number is not 1, then it is a bad number
# If the phone number is more than 11 digits, assume that it is a bad number

# So I'm thinking of storing numbers as array of string and joining only the digits
# So how do I omit characters which are not digits?
# So as per a post on stackoverflow, I can use #delete method with regex like number.delete("^0-9")

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

# So next assignment is to find out which hours of the most people have registered!
# Assignment gives me some documentation about Date and Time classes so I'm going to read it first
# For each row,
# I will use Time.strptime(regdate, directives) to create a time object with date in csv file
# I have to create a method for finding the peak hours
# I will then use #hour method to get hour from Time object
# I will store each hour as keys in hashes and increment their value if certain key appears
# I will sort the hashes by using sorting method
# I can use #sort_by on hash to sort the hours
# Then I extract only the hours as strings
# And store them in a file called peakhours.txt?

def get_hour(time)
  time = Time.strptime(time, '%m/%d/%y %H:%M')
  time.hour.to_s
end

def store_peak_hours(hour_hash, hour)
  hour_hash[hour] = 0 unless hour_hash[hour]
  hour_hash[hour] += 1
end

def sort_hash(hash)
  hash.sort_by {|k, v| -v}.to_h
end

def save_peak_hours(hash)
  filename = "peak_hours.txt"

  File.open(filename, 'w') do |file|
    hash.each do |k, v|
      file.puts "At hour #{k} of the day, #{v} person(s) registered."
    end
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

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true, 
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hour_hash = Hash.new

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  number = clean_phone_number(row[:homephone])
  #binding.pry
  hour = get_hour(row[:regdate])
  legislators = legislators_by_zipcode(zipcode)

  store_peak_hours(hour_hash, hour)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

save_peak_hours(sort_hash(hour_hash))