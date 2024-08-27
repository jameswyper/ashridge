#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
require 'sqlite3'
require 'optparse'


dbfile = ""
OptionParser.new do |opts|
  opts.banner = "Usage: fa_dbs.rb [options]"

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
end.parse!

db = SQLite3::Database.new(dbfile)


class Driver

  attr_reader :wait 

  def webdriver
    @d
  end

  def initialize(site)
      @options = Selenium::WebDriver::Firefox::Options.new
      @d = Selenium::WebDriver.for :remote, url: 'http://localhost:4444', options: @options

      @wait = Selenium::WebDriver::Wait.new(:timeout => 5, :ignore => [Selenium::WebDriver::Error::NoSuchElementError])
      #@d.manage.timeouts.implicit_wait = 10
      @d.manage.delete_all_cookies
      @d.manage.window.resize_to(1920,1080)
      @d.get(site)
  end

  def waitfor(type,tag)
    @wait.until{@d.find_element(type,tag)}
  end

  def find(type,tag,msg=nil,wait=false)
    puts msg if msg
    waitfor(type,tag) if wait
    e = @d.find_elements(type,tag)
    if e.length == 0
      return nil
    else
      if e.length == 1
        return e[0]
      else
        return e
      end
    end
  end

  def click(type,tag,msg=nil,wait=false)
    puts msg if msg
    waitfor(type,tag) if wait
    thing = @d.find_element(type,tag)
    @d.action.move_to(thing,0,-5).perform
    thing.click
    return thing
  end

  def send(type,tag,input,wait=false)
    waitfor(type,tag) if wait
    thing = @d.find_element(type,tag)
    thing.send_keys input
  end
  
  def find_id(tag,msg=nil,wait=false)
    find(:id,tag,msg,wait)
  end
  def find_css(tag,msg=nil,wait=false)
    find(:css,tag,msg,wait)
  end
  def find_link_text(tag,msg=nil,wait=false)
    find(:partial_link_text,tag,msg,wait)
  end

  def quit 
      @d.quit
  end
end

$stdout.sync = true
user, pass = Netrc.read["wholegame.thefa.com"]
puts "Starting.."

begin
  dl = Driver.new('https://wholegame.thefa.com')
  puts "Loaded first page"
  
  c = dl.find_id("onetrust-accept-btn-handler","Looking for cookie pop-up",true)
  sleep 3
  c.click if c
  
  puts "Waiting to sign in"
  dl.send(:id,"signInName", user)
  dl.send(:id,"password", pass)
  dl.click(:id,"next","Signing in..")
  sleep 10
  p = dl.find_id("BtnAcceptCookies","Locating privacy pop-up",true)
  dl.wait.until {p.displayed?}
  dl.click(:id,"BtnAcceptCookies","Closing Privacy pop-up")


  dl.click(:partial_link_text,"Club Secretary","Clicking on Club Secretary Tab")
  dl.click(:partial_link_text,"DBS Applications","Clicking on DBS Applications",true)
  sleep 5
  apps = dl.find_id("crcApplicationsList","Finding applications",true)
  peeps = apps.find_elements(:css,"li.list-group-item.col-md-12")
  peeps.each do |p|
    name = p.find_element(:css,".name").text
    fan = p.find_element(:css,".fan-id").text
    status = p.find_elements(:css,".col-md-2")[1].text
    puts "#{name}/#{fan}/#{status}"
  end

  pages = dl.find_css("li.page-item")
  puts "should say 1: #{pages[1].text}"
  puts "should say next: #{pages[-1].text}"


ensure

dl.quit

end


