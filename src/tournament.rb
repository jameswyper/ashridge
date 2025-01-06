require_relative 'wd_helper'

$stdout.sync = true

begin

  puts "Starting.."
  dl = Driver.new('https://system.gotsport.com/org_event/events/35700')
  sleep 5

  puts "Dealing with any Cookie consent rubbish"

  cookiebuttons = dl.findall_tag('button')
  cookiebuttons.each do |b| 
    if b.text.downcase == "do not consent" 
      b.click 
      break
    end
  end
  sleep 2

  puts "Getting the individual divisions"

  groups = Array.new

  dl.find("#js-no-ages").click
  sleep 2

  ages = dl.find(".m-r-lg").find_elements(tag_name: 'button')
  ages.each do |age|
    puts "Clicking on #{age.text}"
    age.click
    sleep 1
    dl.findall("a.btn.btn-xs.btn-primary-custom.btn-block").each {|e| groups << e.attribute('href')}
  end
  
  puts "Getting teams"
  teams = Array.new
  ugroups = groups.uniq
  i = 1
  s = ugroups.length

  ugroups.each do |group|
    puts "Going to group #{i} of #{s}"
    dl.webdriver.navigate.to(group)
    sleep 2
    tab = dl.find("table.table.table-bordered.table-hover.table-condensed")
    tab.find_elements(tag_name: 'a').each do |team|
      teamid = team.attribute('href').split('=')[-1]
      teamname = team.text
      teams << teamid
      #puts "#{teamid} #{teamname}"
    end
    i = i + 1
  end

  dl.webdriver.navigate.to('https://system.gotsport.com/org_event/events/33875')
  # select none again, then each age
  # https://system.gotsport.com/org_event/events/33875/schedules?age=13&gender=c&page=1  ages 7 to 11 and 13
  # click on each page
  # click on all dates
  # collect all teams and consolidate

ensure
  dl.quit
end