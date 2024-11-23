#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
require 'date'
require 'fileutils'

require_relative 'wd_helper'
$stdout.sync = true
user, pass = Netrc.read["system.gotsport.com"]


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
    puts "Team number = #{tid}"
    puts "Team text = #{tlink}"
    teamnav << [tlink,tid] if tds[3].text.start_with?("EBFA")
  end

teamnav.each {|t| puts t[0]}

ensure

dl.quit

end

# head -1 players_latest.csv | tr [:upper:] [:lower:] | sed -e 's/ /_/g'