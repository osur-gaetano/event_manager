require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.gsub(/[[:punct:] | [:alpha:]]/, '')
  number_format = "(#{phone_number[0..2]})#{phone_number[3..5]}-#{phone_number[6..]}"

  if (phone_number.length < 10 || phone_number.length > 11) || (phone_number.length == 11 && phone_number[0]!='1')
    phone_number = 'Bad phone number format'
  elsif phone_number.size == 11 && phone_number[0] == '1'
    phone_number = phone_number[1..10]
    number_format
    # "(#{phone_number[0..2]})#{phone_number[3..5]}-#{phone_number[6..]}"

  else
    number_format
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def ads_time_targeting(registration_timelines)
  registration_timelines.reduce(Hash.new(0)) do |peak_timeline, timeline|
    peak_timeline[timeline] += 1
    peak_timeline
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
peak_registration_hours = []
peak_registration_days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  registration_date = row[:regdate]
  phone_number = clean_phone_number(row[:homephone])

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  registration_hour = Time.strptime(registration_date, '%m/%d/%y %H:%M').hour
  peak_registration_hours << registration_hour

  registration_day = Date.strptime(registration_date, '%m/%d/%y %H:%M').wday
  peak_registration_days << registration_day

  save_thank_you_letter(id, form_letter)
end
peak_hours = ads_time_targeting(peak_registration_hours)
puts "Peak hours are #{peak_hours.sort_by { |_, value| -value }.to_h}"

peak_days = ads_time_targeting(peak_registration_days)
puts "Peak days are #{peak_days.sort_by { |_, value| -value }.to_h}"
