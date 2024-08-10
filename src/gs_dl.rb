#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
require 'date'
require 'fileutils'
$stdout.sync = true
user, pass = Netrc.read["system.gotsport.com"]

#Firefox will download to here by default
dldir = ENV['HOME']+"/Downloads/"

#clear out old copies

FileUtils.rm_f(dldir + "managers.csv")
FileUtils.rm_f(dldir + "coaches.csv")


class Driver
    def webdriver
      @d
    end
    def initialize(site)
        @options = Selenium::WebDriver::Firefox::Options.new
        @d = Selenium::WebDriver.for :remote, url: 'http://localhost:4444', options: @options

        @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
        @d.manage.timeouts.implicit_wait = 30
        @d.manage.delete_all_cookies
        @d.manage.window.resize_to(1920,1080)
        @d.get(site)
    end
    def click(css,msg=nil)
      puts msg if msg
        @wait.until {@d.find_element(:css,css)}
        thing = @d.find_element(:css,css)
        @d.action.move_to(thing,0,-5).perform
        thing.click
        return thing
    end
    def send(css,input)
        @wait.until {@d.find_element(:css,css)}
        thing = @d.find_element(:css,css)
        thing.send_keys input
    end
    def find(css,msg=nil)
        puts msg if msg
        @wait.until {@d.find_element(:css,css)}
        return @d.find_element(:css,css)
    end
    def quit 
        @d.quit
    end
end



puts "Starting.. User is #{user}"
begin

    dl = Driver.new('https://system.gotsport.com')
  

    sleep 15

    puts "Waiting to sign in"

    dl.send('#user_email',user)
    dl.send('#user_password',pass)
    sleep 0.1
    dl.click('.m-b-sm','Signing in..')
    
    sleep 15

# get org ID

  orgid = dl.find('a.active').attribute('href').split("/")[-1]
  puts "Org ID is #{orgid}"
  
  rooturl = 'https://system.gotsport.com/org/'+orgid + '/'

#request downloads from the teams, coaches, managers and player pages
# start by exporting teams

  puts "Moving to Teams page"
  dl.webdriver.navigate.to(rooturl + 'teams')
  sleep 10

  dl.click('div.pull-right:nth-child(2)',"Clicking on hamburger menu")
  sleep 0.1

  dl.click('div.pull-right:nth-child(2) > ul:nth-child(2) > li:nth-child(1) > a:nth-child(1)',"Clicking on Export for Teams")
  sleep 1

  dl.click('.js-select-all-col-checkbox',"Clicking on Select All")
  sleep 0.5

  dl.click('input.js-target-disable-with-checkbox',"Clicking on Export/Download")
  sleep 5

  dl.click('.modal-sm > div:nth-child(1) > div:nth-child(1) > button:nth-child(1)',"Dismissing pop-up")
  
# next export players. First all players (don't use any search filters)
  playerexports = ["all"]
  puts "Moving to Players page"
  dl.webdriver.navigate.to(rooturl + 'players')
  sleep 10


  dl.click('a.small-margin-right',"Clicking on Export for Players")
  sleep 5
  dl.click('.modal-sm > div:nth-child(1) > div:nth-child(1) > button:nth-child(1)',"Dismissing pop-up")


  # then export each saved search - firstly find them and store them (we can't iterate over the options because the web elements go stale)

  searches = Array.new
  savedsearches = dl.find('#saved_report_id',"Finding Saved Searches list")
  sselect = Selenium::WebDriver::Support::Select.new(savedsearches)
  sselect.options.each do |o| 
    if o.text != "Select Saved Search" 
      searches << o.text
    end
  end
  
  searches.each do |s|
    puts "Reloading players page"
    dl.webdriver.navigate.to(rooturl + 'players')
    sleep 10
    puts "Selecting #{s}"
    savedsearches = dl.find('#saved_report_id',"Finding Saved Searches list")
    sselect = Selenium::WebDriver::Support::Select.new(savedsearches)
    sselect.select_by(:text,s)
    dl.click('.btn-block',"Clicking on first Search button to bring up correct filters")
    sleep 2
    if s.include?("ByTeam")
      filterlist = dl.find('.filters-list',"Finding filters")
      j = 0
      f = -1
      filterlist.find_elements(:class,'row').each do |r|
        fs = r.find_element(:css,'#filters_filt-' + j.to_s + '_type')
        fselect = Selenium::WebDriver::Support::Select.new(fs)
        if fselect.selected_options[0].text == "Player Team"
          f = j + 1
        end
        j = j + 1
      end
      if (f < 1) 
        puts "WARNING For search #{s} should have found a Player Team filter?"
      else
        dl.click('div.search-filter:nth-child('+f.to_s+') > div:nth-child(1) > div:nth-child(4) > a:nth-child(1)',"For search #{s}: " + "Found Player Team filter; removing it")

        dl.click('input.btn-xs',"Clicking on second Search button to run the search")
        sleep 10 
      end
    end


    puts dl.find('li.fz-sm',"Getting result count..").text
    # our filters are set and the search run and we can download. Save the name of the filter in an array for later first
    playerexports << s
    dl.click('a.small-margin-right',"Clicking on Export for Players")
    sleep 5
    dl.click('.modal-sm > div:nth-child(1) > div:nth-child(1) > button:nth-child(1)',"Dismissing pop-up")
    sleep 3
  end

  # now export coaches and managers (which is thankfully easy)


  puts "Moving to Coaches page"
  dl.webdriver.navigate.to(rooturl + 'coaches')
  sleep 15
  dl.click('a.btn-default',"Clicking on Export for Coaches")
  sleep 5
  
  puts "Moving to Managers page"
  dl.webdriver.navigate.to(rooturl + 'managers')
  sleep 15
  dl.click('a.btn-default',"Clicking on Export for Managers")

  sleep 15



# Actually locate and download the requested files from the Download page

  puts "Moving to Downloads page"
  dl.webdriver.navigate.to(rooturl + 'downloads')
  sleep 10

  dltable = dl.find('.table > tbody:nth-child(2)',"Finding download table")
  puts "Finding table rows"
  dlrows = dltable.find_elements(:tag_name,'tr')
  puts "Download table has #{dlrows.size} rows"

  # go through the table of downloads and match up to the expected exports

  dltypes = {"teams": ["all"], "players": playerexports}
  dlactual = Hash.new
  i = 1
  dlrows.each do |r|
    e = r.find_element(:css,'tr:nth-child(' + i.to_s + ') > td:nth-child(1) > a:nth-child(1)')
    puts "Element text at row #{i.to_s} is #{e.text}"
    dltypes.each do |k,v|
      # if we find a download of the appropriate type
      if e.text.start_with?(k.to_s) && v.size > 0
        e.click
        sleep 2
        dest = (k.to_s + "_" + v.pop + ".csv").gsub(" ","_").gsub("/","-").gsub("(","_").gsub(")","_")
        dlactual[dest] = e.text
      end
    end
    i = i + 1
  end
    
# move the files to teams_all.csv, and players_all / players_<EBFA search filter name> to make subsequent processing easier
# managers and coaches should already be in dldir as managers.csv and coaches.csv


  
  dlactual.each do |k,v|
    dest = dldir + k
    src = dldir + v
    FileUtils.rm_f(dest)
    puts "Moving #{src} to #{dest}"
    FileUtils.mv(src,dest)
  end



ensure

dl.quit

end

# head -1 players_latest.csv | tr [:upper:] [:lower:] | sed -e 's/ /_/g'