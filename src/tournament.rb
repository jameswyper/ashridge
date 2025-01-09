require_relative 'wd_helper'
require 'csv'

$stdout.sync = true

begin

  puts "Starting.."
  teams = Array.new
  
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

  begin

    puts "Getting the individual divisions for older age groups"

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
    
    ugroups = groups.uniq
    i = 1
    s = ugroups.length
    
    #ugroups = [ugroups[0]] -- only for testing

    ugroups.each do |group|
      puts "Going to group #{i} of #{s}"
      dl.webdriver.navigate.to(group)
      sleep 2
      tab = dl.find("table.table.table-bordered.table-hover.table-condensed")
      tab.find_elements(tag_name: 'a').each do |team|
        teamid = team.attribute('href').split('=')[-1]
        #teamname = team.text
        teams << teamid
        #puts "#{teamid} #{teamname}"
      end
      i = i + 1
    end
  end
 
  begin
    dl.webdriver.navigate.to('https://system.gotsport.com/org_event/events/33875')

    puts "Getting the divisions for younger age groups"
    
    groups = Array.new
    youngteams = Array.new
    ages = dl.find(".m-r-lg").find_elements(tag_name: 'button')
    ages.each do |age|
      groups << age.text.chop
    end
    puts "Found #{groups.join(",")}"

    groups.each do |group|
      puts "Getting teams for Age Group #{group}"
      dl.webdriver.navigate.to("https://system.gotsport.com/org_event/events/33875/schedules?age=#{group}&gender=c&page=1")
      pages = Array.new
      dl.find('ul.pagination').find_elements(css: '.page-link').each do |link|
        pages << link.text if Integer(link.text, exception: false)
      end
      puts "Found pages #{pages.join(",")}"
      pages.each do |page|
        unless page == "1"
          dl.webdriver.navigate.to("https://system.gotsport.com/org_event/events/33875/schedules?age=#{group}&gender=c&page=#{page}")
          sleep 1
          dl.find(".btn-primary.btn-xs.pull-right").click
          sleep 1
          dl.webdriver.find_elements(tag_name: 'a').each do |c|
            l = c.attribute('href')
            if l =~ /https:\/\/system.gotsport.com\/org_event\/events\/.*\/schedules\?team=(.*)$/
              youngteams << $1
            end
          end
        end
      end
    end
  end
  youngteams.uniq!

  i = 1
  s = teams.length + youngteams.length
  puts "#{s} teams to get contact details for"
  
  CSV.open("/home/james/contacts.csv","w") do |csv|
    csv << ["Team","Role","Name","Email","Phone"]
    allteams = [["35700",teams],["33875",youngteams]]
    allteams.each do |combo|  
      combo[1].each do |team|
        dl.webdriver.navigate.to("https://system.gotsport.com/org_event/events/#{combo[0]}/contacts?team=#{team}")
        header = dl.find('.lead').text
        puts "Getting contacts for team #{i} of #{s}, #{header.split(' Contact Information')[0]}"
        i = i + 1
        tab = dl.find('.table')
        tab.find_elements(tag_name: 'tr').each do |r|
          row = [header.split(' Contact Information')[0]]
          r.find_elements(tag_name: 'td').each do |i|
            row << i.text
          end
          csv << row
        end
      end
    end
  end
ensure
  dl.quit
end