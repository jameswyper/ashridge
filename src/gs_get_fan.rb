#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
require 'date'
require 'fileutils'
$stdout.sync = true
user, pass = Netrc.read["system.gotsport.com"]

#Firefox will download to here by default
#dldir = ENV['HOME']+"/Downloads/"

#clear out old copies


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


  
# next export players. First all players (don't use any search filters)

  puts "Moving to Players page"
  dl.webdriver.navigate.to(rooturl + 'players')
  sleep 10

  pagesize = 100
  org2id = dl.find('.nav > li:nth-child(1) > a:nth-child(1)').attribute('href').split("/")[-2]
  puts "Other Org ID is #{org2id}"
  rc = dl.find('li.fz-sm',"Getting result count..").text
  total = rc[/.*of (.*) in total.*/,1].to_i
  pages = (total / pagesize).floor + 1
  puts "#{rc} so #{pages} pages of #{pagesize}"

  playurl = 'https://system.gotsport.com/org/' + org2id + "/players?utf8=%E2%9C%93&per_page=" + pagesize.to_s + "&page="
  
  for page in 1..pages do 
  
    dl.webdriver.navigate.to(playurl + page.to_s)

    table = dl.find('#players-table > tbody:nth-child(2)',"Locating player table")
    rows = table.find_elements(tag_name: 'tr')
    purls = Array.new
    rows.each do |row|
      p = row.find_element(css: 'td:nth-child(2) > div:nth-child(1) > div:nth-child(2) > a:nth-child(1)')
      purls << p.attribute('href')
    end
    
    purls[0..pagesize].each do |purl|

      dl.webdriver.navigate.to(purl)
      sleep 1
      firstname = dl.find('#user_first_name').attribute('value')
      readonly = dl.find('#user_first_name').attribute('readonly')
      lastname = dl.find('#user_last_name').attribute('value')

      
      begin
        f = dl.webdriver.find_element(css: '#user_fan_number')
      rescue Selenium::WebDriver::Error::NoSuchElementError
        f = nil
      end

      if f
        fan = f.attribute('value')
        fanlocked = f.attribute('readonly')
      else
        fan = nil
        fanlocked = nil
      end

      itc_birth = Selenium::WebDriver::Support::Select.new(dl.find('#user_itc_country_of_birth')).selected_options[0].text
      itc_citz = Selenium::WebDriver::Support::Select.new(dl.find('#user_itc_country_of_citizenship_')).selected_options[0].text
      birthyear = Selenium::WebDriver::Support::Select.new(dl.find('#user_birthdate_1i')).selected_options[0].text
      birthmonth = Selenium::WebDriver::Support::Select.new(dl.find('#user_birthdate_2i')).selected_options[0].text
      birthday = Selenium::WebDriver::Support::Select.new(dl.find('#user_birthdate_3i')).selected_options[0].text

      puts "#{firstname} #{lastname} - Locked? #{readonly} - #{birthyear}-#{birthmonth}-#{birthday} #{itc_birth} #{itc_citz} FAN:#{fan} #{fanlocked}"

    end
  end

ensure

  dl.quit

end


#    #user-13910211 > td:nth-child(2) > div:nth-child(1) > div:nth-child(2) > a:nth-child(1)
  