#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'net/imap'
require 'netrc'
require 'mail'

class Driver
  attr_reader :wait
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
  
  def click_link_text(text,msg=nil)
    puts msg if msg
      @wait.until {@d.find_element(:partial_link_text,text)}
      thing = @d.find_element(:partial_link_text,text)
      @d.action.move_to(thing,0,-5).perform
      thing.click
      return thing
  end

  def click_id(id,msg=nil)
    puts msg if msg
      @wait.until {@d.find_element(:id,id)}
      thing = @d.find_element(:id,id)
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

  def find_link_text(t,msg=nil)
    puts msg if msg
    @wait.until {@d.find_element(link_text: t)}
    return @d.find_element(link_text: t)
  end

  def quit 
      @d.quit
  end

  def findall(css,msg=nil)
    puts msg if msg
    e = @d.find_elements(:css,css)
    return e
  end

  def findall_tag(id,msg=nil)
    puts msg if msg
    return @d.find_elements(:tag,tag)
  end

  def selector(name,msg=nil)
    puts msg if msg
    select_element = @d.find_element(name: name)
    return Selenium::WebDriver::Support::Select.new(select_element)
  end
   
  def gsSignIn(user,password)
    sleep 10

    puts "Waiting to sign in"

    e = findall('button.fc-button.fc-cta-do-not-consent.fc-secondary-button','Check for cookie consent dialog')
    e[0].click unless e.nil?

    user, password = Netrc.read["system.gotsport.com"]
    send('#user_email',user)
    send('#user_password',password)
    sleep 0.1
    click('.m-b-sm','Signing in..')
    
    sleep 10
  end

  def faSignIn(user,password)
    
    sleep 3

    puts "Loaded first page, waiting for cookie pop-up"
    begin
        click('#onetrust-accept-btn-handler')
    rescue Selenium::WebDriver::Error
    end

    sleep 1

    puts "Entering credentials"
    send('#signInName',user)
    send('#password',password)
    sleep 0.1
    click('html body div#panel.panel table.panel_layout tbody tr.panel_layout_row td#panel_center div.inner_container div.api_container.normaltext div#api form#localAccountForm.localAccount div.entry div.buttons button#next',"Signing In..")
    sleep 3

    click("#emailVerificationControl_but_send_code","Clicking SEND CODE button")

  end

  def faEnterCode(code)
    send("#VerificationCode",code)
    sleep 0.2
    click("#emailVerificationControl_but_verify_code","Clicking VERIFY CODE button")
    sleep 0.5
    click("#continue","Clicking CONTINUE button")
  end

end

class CodeMail

  attr_reader :code 

  def initialize(server,port,inbox,netrc)
    imap = Net::IMAP.new(server,port, true)
    user, pass = Netrc.read[netrc]
    imap.login(user, pass)
    imap.examine(inbox)
    codemails = imap.search(["SUBJECT", "Your FA account email verification code"])
    imapmail = imap.fetch(codemails[-1],"RFC822")[0]
    mail = Mail.new(imapmail.attr["RFC822"])
    mat = /Your code is: ([0-9]{6})/.match(mail.parts[1].decoded)
    @code = mat[1]
    imap.logout
  end

end

