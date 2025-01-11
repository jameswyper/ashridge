require_relative 'wd_helper'
require 'csv'

$stdout.sync = true


class Team
  attr_reader :name, :id, :event, :originURL
  def initialize(n, i, e, o)
    @name = n
    @id = i
    @event = e
    @originURL = o
  end
end

debug = false

OLDEVENT = 35700
YOUNGEVENT = 33875

begin

  puts "Starting.."
  teams = Array.new

  dl = Driver.new("https://system.gotsport.com/org_event/events/#{OLDEVENT}")
  
  
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
    
    ugroups = [ugroups[0]] if debug

    ugroups.each do |group|
      puts "Going to group #{i} of #{s}"
      dl.webdriver.navigate.to(group)
      sleep 2
      tab = dl.find("table.table.table-bordered.table-hover.table-condensed")
      tab.find_elements(tag_name: 'a').each do |team|
        teamid = team.attribute('href').split('=')[-1]
        teamname = team.text
        teams << Team.new(teamname, teamid, OLDEVENT, group)
        #puts "#{teamid} #{teamname}"
      end
      i = i + 1
    end
  end
 
  puts "Found #{teams.size} teams in total"
   
  begin
    dl.webdriver.navigate.to("https://system.gotsport.com/org_event/events/#{YOUNGEVENT}")

    puts "Getting the divisions for younger age groups"
    
    groups = Array.new
    youngteams = Array.new
    ages = dl.find(".m-r-lg").find_elements(tag_name: 'button')
    ages.each do |age|
      groups << age.text.chop
    end
    puts "Found #{groups.join(",")}"

    groups = [groups[0]] if debug

    groups.each do |group|
      puts "Getting teams for Age Group #{group}"
      url = "https://system.gotsport.com/org_event/events/#{YOUNGEVENT}/schedules?age=#{group}&gender=c&page=1"
      dl.webdriver.navigate.to(url)
      pages = Array.new
      dl.find('ul.pagination').find_elements(css: '.page-link').each do |link|
        pages << link.text if Integer(link.text, exception: false)
      end
      puts "Found pages #{pages.join(",")}"
      pages.each do |page|
        unless page == "1"
          url = "https://system.gotsport.com/org_event/events/#{YOUNGEVENT}/schedules?age=#{group}&gender=c&page=#{page}"
          dl.webdriver.navigate.to(url)
          sleep 1
        end
        puts "Page #{page}"
        dl.find(".btn-primary.btn-xs.pull-right").click
        sleep 1
        dl.webdriver.find_elements(tag_name: 'a').each do |c|
          l = c.attribute('href')
          if l =~ /https:\/\/system.gotsport.com\/org_event\/events\/.*\/schedules\?team=(.*)$/
            youngteams << Team.new(c.text,$1,YOUNGEVENT,url)
          end
        end
      end
    end
  end
  
  youngteams.sort! {|x,y| x.id <=> y.id}
  uniqyoungteams = youngteams.uniq {|t| t.id}
  puts "Found #{youngteams.size} teams in total of which #{uniqyoungteams.size} are unique"
  uniqyoungteams.each {|y| puts "#{y.name} #{y.name.object_id} #{y.id} #{y.id.object_id} #{y.originURL}"}  if debug
  teams = teams + uniqyoungteams

  i = 1
  s = teams.length 
  puts "#{s} teams to get contact details for overall"
  
  CSV.open("/home/james/contacts.csv","w") do |csv|
    csv << ["Team","Role","Name","Email","Phone"]
    teams.each do |team|
      url = "https://system.gotsport.com/org_event/events/#{team.event}/contacts?team=#{team.id}"      
      puts "Getting contacts for team #{i} of #{s}: #{team.name} from #{url} original source #{team.originURL}"
      dl.webdriver.navigate.to(url)
      contact = dl.findall('.lead') # some teams don't publish contact details

      if contact.size > 0
        header = contact[0].text
        tab = dl.find('.table')
        tab.find_elements(tag_name: 'tr').each do |r|
          row = [header.split(' Contact Information')[0]]
          r.find_elements(tag_name: 'td').each do |i|
            row << i.text
          end
          csv << row
        end
      else
        csv << [team.name,"Not published","","",""]
      end

      i = i + 1
    end
  end
ensure
  dl.quit
end