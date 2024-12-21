#!/usr/bin/env ruby

require 'netrc'
require 'date'
require 'fileutils'
require 'csv'
require 'optparse'
require_relative 'wd_helper'
$stdout.sync = true
user, pass = Netrc.read["system.gotsport.com"]

mgrfile = ""
coachfile = ""
teamsfile = ""
outfile = ""
OptionParser.new do |opts|
  opts.banner = "Usage: gs_mgr_dl.rb [options]"

  opts.on("-m", "--manager MMMM",  "Path to Manager extract") do |u|
    mgrfile = u
  end

  opts.on("-c", "--coach CCCC",  "Path to Coach extract") do |u|
    coachfile = u
  end

  opts.on("-t", "--team TTTT",  "Path to Teams Extract") do |u|
    teamsfile = u
  end

  opts.on("-o", "--output OOOO",  "Path to output file") do |u|
    outfile = u
  end

end.parse!



officials = Array.new
teams = Hash.new
output = Array.new

CSV.foreach(mgrfile, headers: true) do |row|
   officials << {id: row["Id Number"], role: "managers"}
end 

CSV.foreach(coachfile, headers: true) do |row|
  officials << {id: row["Id Number"], role: "coaches"}
end 

org = ""
CSV.foreach(teamsfile, headers: true) do |row|
  teams[row["Team ID"]] = {name: row["Team"], level: row["Level"]} 
  org = row["Club ID"]
end 


=begin
read managers, coaches and teams into two tables (combine mgr and coach)
go to the page for each mgr/coach
get a team that's an EBFA one
capture the photo and DOB
open the squad url
capture the FAN

=end


puts "Starting.. User is #{user} #{Time.now}"
begin

    dl = Driver.new('https://system.gotsport.com')
  
    dl.gsSignIn(user,pass)

# get org ID

  orgid = dl.find('a.active').attribute('href').split("/")[-1]
  
  rooturl = 'https://system.gotsport.com/org/'+orgid + '/'

  orgnum = dl.find('li.nav-item:nth-child(5) > a:nth-child(1)','looking for org number').attribute('href').split('/')[-2]

  #puts "Org ID is #{orgid} and the *other* Org ID is #{orgnum} and csv Org Id is #{org}"

  officials.each do |o|
    
    mgrurl = rooturl + o[:role] + "/" + o[:id]
    puts "going to #{mgrurl}"
    dl.webdriver.navigate.to(mgrurl)
    sleep 4

    teamdiv = dl.find('.col-md-8 > div:nth-child(1) > div:nth-child(3) > div:nth-child(2) > div:nth-child(6) > div:nth-child(2)','finding teams div')
    ebfateamid = ""
    if teamdiv.find_elements(:css,'*').length == 0
      #puts "Manager has no teams"
    else
      teamtable = dl.find(".table","looking for team table")
      teamrows = teamtable.find_elements(:css,'tbody > tr')
      teamrows.each do |team|
        teamid = team.attribute('id').split('-')[-1]
        t = teams[teamid]
        roles = team.find_element(:css,'td:nth-child(4)').text
        #puts "found #{t[:name]} roles #{roles}"
        if (t[:level].start_with? "EBFA") && ((o[:role] == "managers" && roles.include?("manager")) || (o[:role] == "coaches" && roles.include?("coach")) )
          #needs to be EBFA team AND role matches manager or coach
          ebfateamid = teamid
        end

      end
    end
    
    #.col-md-8 > div:nth-child(1) > div:nth-child(3) > div:nth-child(2) > div:nth-child(6) > div:nth-child(2)
    #.col-md-8 > div:nth-child(1) > div:nth-child(3) > div:nth-child(2) > div:nth-child(6) > div:nth-child(2)
    
    photo = dl.find('.avatar-lg > img:nth-child(1)', 'Looking for photo').attribute('src')
    
    #no photo = /users/photos/default.png
    
    dob = dl.find('div.m-b-sm:nth-child(10) > div:nth-child(2) > p:nth-child(1)','looking for ID').text
    userid = dl.find('.col-md-8 > div:nth-child(1) > div:nth-child(3) > div:nth-child(5) > div:nth-child(2) > div:nth-child(2) > p:nth-child(1)','Looking for user ID').text
      
    #puts "For id #{o[:id]} type #{o[:role]} user ID is #{userid} DOB #{dob} EBFA team: #{ebfateamid} photo URL #{photo} "
    
   

    fan = ""
    if ebfateamid != ""

      urltail = o[:role] == "managers" ? "TeamManager" : "TeamCoach"
      navurl = "https://system.gotsport.com/users/#{userid}?current_org_id=#{org}&org_id=#{org}&resource_id=#{ebfateamid}&resource_type=Team&type=#{urltail}"
      dl.webdriver.navigate.to(navurl)
      #puts navurl

      country = dl.webdriver.find_element(:id,'user_address_attributes_country')
      country_select = Selenium::WebDriver::Support::Select.new(country).selected_options

      if (country_select.length == 1) && (country_select[0].attribute('value') == "GB")
        #puts "UK address"
        fan = dl.webdriver.find_element(:id,'user_fan_number').attribute('value')
      end

    end
    #puts "fan is #{fan}"

    output << [o[:id],o[:role],userid,fan,dob,photo]
  end

  CSV.open(outfile,"w") do |csv|
    csv << ["id","role","user_id","fan","DOB","photo"]
    output.each {|o| csv << o }
  end

ensure

dl.quit

end

puts "finished at #{Time.now}"