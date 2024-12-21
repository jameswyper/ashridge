#!/usr/bin/env ruby
require_relative 'wd_helper'
require 'netrc'
require 'sqlite3'
require 'optparse'

$stdout.sync = true

dbfile = ""
OptionParser.new do |opts|
  opts.banner = "Usage: fa_complete.rb [options]"

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
end.parse!

db = SQLite3::Database.new(dbfile)
db.execute("drop table if exists raw_fa_dbs;")
db.execute("create table raw_fa_dbs (name,fan,status,last_award_date);")



user, pass = Netrc.read["wholegame.thefa.com"]

begin

  dl = Driver.new('https://clubs.thefa.com')
  
  puts "Starting"
  dl.faSignIn(user,pass)

  puts "Pausing to allow email to arrive"
  sleep 20
  x = CodeMail.new("imap.googlemail.com", 993,"[Gmail]/All Mail","gmail.com")

  dl.faEnterCode(x.code)

  # Get Officials listing

  dl.click('#primary-navigation > div.main-ctr > div.navigation-menu > div.module-ctr > div:nth-child(5)',"Going to Officials")
  dl.click('#secondary-navigation > div > div:nth-child(3)',"Going to Safeguarding")
  sleep 5
  dl.click('#safeguarding-listing > div.fixed-content > div.toolbar-ctr > div.top-bar > div > div:nth-child(2) > button',"Clicking Export")
  sleep 2
  dl.click('#export-officials > div.popup-body > div.dialog-actions > button.dialog-btn.emphasised-btn.fa-blue',"Clicking Download")
  sleep 5

  # Get Players listing


  dl.click(".module-ctr > div:nth-child(3) > div:nth-child(2)","Going to Players")
  dl.click("button.mat-menu-trigger:nth-child(2)","Clicking Export")
  sleep 2
  dl.click(".menu-content > button:nth-child(3)","Clicking Player")
  sleep 2
  dl.click("button.dialog-btn.emphasised-btn.fa-blue","Clicking Confirm")
  sleep 15

  # Go to Club then Download page, repeat until all downloads are ready
  pending = 2
  until pending == 0 do
    pending = 2
    sleep 7  
    dl.click(".module-ctr > div:nth-child(2)","Clicking on My Club")
    sleep 1
    dl.click('div.cursor-pointer:nth-child(2) > span:nth-child(1)',"Clicking on Documentation")
    sleep 1
    2.times do |r|
       filename = dl.find("div.table-row:nth-child(#{r+1}) > div:nth-child(1) > div:nth-child(2)").text
       status = dl.find("div.table-row:nth-child(#{r+1}) > div:nth-child(3) > div:nth-child(1) > div:nth-child(1) > app-status-indicator:nth-child(1) > div:nth-child(1) > div:nth-child(2)").text
       if status.strip == "Completed"
         pending = pending - 1
       end
       puts "File #{filename} has status #{status}"
    end
  end
 
  2.times do |r|
    sleep 3
    dl.click("div.table-row:nth-child(#{r+1}) > div:nth-child(4) > div:nth-child(1) > img:nth-child(1)","Downloading row #{r+1}")
  end
  
  # Get DBS application status

  dl.click(".p-l-r10 > div:nth-child(1) > div:nth-child(2)","Clicking on Wholegame Link")

  sleep 10

  p = dl.find_id("BtnAcceptCookies","Locating privacy pop-up")
  dl.wait.until {p.displayed?}
  dl.click_id("BtnAcceptCookies","Closing Privacy pop-up")
  
  dl.click_link_text("Club Secretary","Clicking on Club Secretary Tab")
  dl.click_link_text("DBS Applications","Clicking on DBS Applications")
  sleep 5

  pages = dl.findall("li.page-item")

  loop do
    morepages = pages[-1].find_element(:css,"a.page-link").displayed?
    apps = dl.find_id("crcApplicationsList","Finding applications")
    peeps = apps.find_elements(:css,"li.list-group-item.col-md-12")
    peeps.each do |p|
      name = p.find_element(:css,".name").text
      fan = p.find_element(:css,".fan-id").text
      status = p.find_elements(:css,".col-md-2")[1].text
      date = p.find_element(:css,".btn").text
      puts "#{name} #{fan[1..-1]}"  
      db.execute("insert into raw_fa_dbs (name,fan,status,last_award_date) values (?,?,?,?);",name,fan[1..-1],status,date)
    end
    if morepages
      pages[-1].find_element(:css,"a.page-link").click 
      sleep 3
      pages = dl.findall("li.page-item")
    end
    break unless morepages
  end 

  
ensure
  dl.quit
end

