#!/usr/bin/env ruby
require_relative 'wd_helper'
require 'netrc'
require 'sqlite3'
require 'optparse'

$stdout.sync = true

user, pass = Netrc.read["wholegame.thefa.com"]

begin

  dl = Driver.new('https://clubs.thefa.com')
  
  puts "Starting"
  email_incoming = dl.faSignIn(user,pass)

  if email_incoming
    puts "Pausing to allow email to arrive"
    sleep 20
    x = CodeMail.new("fa","imap.googlemail.com", 993,"[Gmail]/All Mail","gmail.com")

    dl.faEnterCode(x.code)
  end

  # Get Officials listing

  dl.click('a.gap20:nth-child(4)',"Going to Officials")


  
  
  dl.click('a.sec-nav-tab:nth-child(3)',"Going to Safeguarding")
  sleep 5
  dl.click('#btn-all-officials-safeguarding-and-qualification-export-team-officials > div:nth-child(1)',"Clicking Export")
  sleep 2
  dl.click('.mat-mdc-dialog-actions > lib-button:nth-child(2)',"Clicking Confirm")
  sleep 5

  # Get Players listing


  dl.click("#link-primary-navigation--Players","Going to Players")
  dl.click("lib-button.mat-mdc-menu-trigger","Clicking Export")
  sleep 2
  dl.click("button.mat-mdc-menu-item:nth-child(3) > span:nth-child(1)","Clicking Player")
  sleep 2
  dl.click(".mat-mdc-dialog-actions > lib-button:nth-child(2)","Clicking Confirm")
  sleep 15

  # Go to Club then Download page, repeat until all downloads are ready
  filelinks = []
  pending = 2
  until pending == 0 do
    pending = 2
    sleep 7  
    dl.click("#link-primary-navigation--My\\ Club","Clicking on My Club")
    sleep 1
    dl.click('nav.primary > a:nth-child(2)',"Clicking on Documentation")
    sleep 1
    2.times do |r|
       filename = dl.find("div.details-table-row:nth-child(#{r+2}) > div:nth-child(1)").text
       status = dl.find("div.details-table-row:nth-child(#{r+2}) > div:nth-child(3) > lib-status-indicator:nth-child(1) > span:nth-child(1) > span:nth-child(2)").text
       if status.strip == "Completed"
         pending = pending - 1
         filelinks << "#link-my-downloads-download-document-" + filename.gsub(" ","\\ ").gsub(".","\\.")
       end
       puts "File #{filename} has status #{status}"
    end
  end
 
  filelinks.each do |f|
    sleep 3
    dl.click(f,"Clicking on #{f} link")
  end
  
  sleep 3
   
ensure
  dl.quit
end

