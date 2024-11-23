#!/usr/bin/env ruby
require 'selenium-webdriver'

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

  def find_id(id,msg=nil)
    puts msg if msg
    @wait.until {@d.find_element(:id,id)}
    return @d.find_element(:id,id)
  end

  def quit 
      @d.quit
  end

  def exists(css,msg=nil)
    puts msg if msg
    e = @d.find_elements(:css,css)
    return e
  end

  def findall_tag(id,msg=nil)
    puts msg if msg
    return @d.find_elements(:tag,tag)
  end

  def signIn(user,password)
    sleep 10

    puts "Waiting to sign in"

    e = exists('button.fc-button.fc-cta-do-not-consent.fc-secondary-button','Check for cookie consent dialog')
    e[0].click unless e.nil?

    send('#user_email',user)
    send('#user_password',password)
    sleep 0.1
    click('.m-b-sm','Signing in..')
    
    sleep 10
  end

end
