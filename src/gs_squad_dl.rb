#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
require 'optparse'
require 'fileutils'
require 'csv'

require_relative 'wd_helper'
$stdout.sync = true
user, pass = Netrc.read["system.gotsport.com"]

outdir = "/tmp"
OptionParser.new do |opts|
  opts.banner = "Usage: gs_squad_dl.rb [options]"

  opts.on("-d", "--directory DDDD",  "Output Directory") do |u|
    outdir = u
  end
end.parse!




allplayers = [["teamid","teamname","id","name","jersey","status"]]
allmgrs = [["teamid","teamname","id","name","tick"]]
allcoaches = [["teamid","teamname","id","name","role"]]

puts "Starting.. User is #{user}"
begin

    dl = Driver.new('https://system.gotsport.com')
  
    dl.signIn(user,pass)


# get org ID

  orgid = dl.find('a.active').attribute('href').split("/")[-1]
  puts "Org ID is #{orgid}"
  
  rooturl = 'https://system.gotsport.com/org/'+orgid + '/'

# go to teams page

  puts "Moving to Teams page"
  dl.webdriver.navigate.to(rooturl + 'teams')
  sleep 10
  teamnav = Array.new
  tt = dl.find_id("teams-table","Getting Teams table")
  tb = tt.find_elements(tag_name: "tbody")[0]
  trs = tb.find_elements(tag_name: "tr")
  trs.each do |tr|
    tds = tr.find_elements(tag_name: "td")
    tinfo = tds[1]
    tlink = tinfo.find_elements(tag_name: "a")[0].text
    tid = tinfo.find_elements(tag_name: "p")[0].text
    #puts "Team number = #{tid}"
    #puts "Team text = #{tlink}"
    teamnav << [tlink,tid] if tds[3].text.start_with?("EBFA")
  end

teamnav.each do |t|
   dl.find_link_text(t[0],"Bringing up modal dialog for #{t[0]}").click
   sleep 3
   dl.find_id("Squads-tab-link","Clicking on Squads").click
   sleep 2
   s = dl.selector("event_id","Finding Select Box")
   s.select_by(:value ,"34237") # will need to change in future years
   dl.find("#rosters > form > div > div.form-group.col-md-2 > input","Clicking Search").click


   ptt = dl.find_id("roster-player-table","Finding Players table")
   ptrs = ptt.find_elements(tag_name: "tbody")[0].find_elements(tag_name: "tr") 
   ptrs.each do |ptr|
     prec = [t[1],t[0]]
     prec << ptr.attribute("id").split("-")[1] #id number
     ptds = ptr.find_elements(tag_name: "td")
     prec << ptds[0].find_element(tag_name: "a").text #name
     prec << ptds[3].find_elements(css: '[id^="roster-jersey"]')[0].attribute("value") #jersey
     prec << ptds[7].text.strip
     allplayers << prec
   end

   dl.find_id("event-roster-managers-tab-link").click

   mtt = dl.find_id("roster-manager-table","Finding Managers table")
   mtrs = mtt.find_elements(tag_name: "tbody")[0].find_elements(tag_name: "tr") 
   mtrs.each do |mtr|
    mrec = [t[1],t[0]]
    mrec << mtr.attribute("id").split("-")[1] #id number
    mtds = mtr.find_elements(tag_name: "td")
    mrec << mtds[0].find_element(tag_name: "a").text #name
    mrec << mtds[2].text.strip #fa-check
    allmgrs << mrec
   end
   
   dl.find_id("event-roster-coaches-tab-link").click

   ctt = dl.find_id("roster-coach-table","Finding Coaches table")
   ctrs = ctt.find_elements(tag_name: "tbody")[0].find_elements(tag_name: "tr")
   unless ctrs[0].find_elements(tag_name: "td")[0].text == "No Coaches"
      ctrs.each do |ctr|
        crec = [t[1],t[0]]
        crec << ctr.attribute("id").split("-")[1] #id number
        ctds = ctr.find_elements(tag_name: "td")
        crec << ctds[0].find_element(tag_name: "a").text #name
        crec << Selenium::WebDriver::Support::Select.new(ctds[2].find_element(id: 'roster_title')).selected_options[0].text #role
        allcoaches << crec
      end
   end

   dl.find("#global-modal > div > div > div.modal-header > button","Closing").click
end

File.write(outdir+"/squadplayer.csv",allplayers.map(&:to_csv).join)
File.write(outdir+"/squadmgr.csv",allmgrs.map(&:to_csv).join)
File.write(outdir+"/squadcoach.csv",allcoaches.map(&:to_csv).join)
ensure

dl.quit

end

# head -1 players_latest.csv | tr [:upper:] [:lower:] | sed -e 's/ /_/g'