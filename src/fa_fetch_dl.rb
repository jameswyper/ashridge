
require 'selenium-webdriver'
require 'netrc'
$stdout.sync = true
user, pass = Netrc.read["wholegame.thefa.com"]


class Driver
    def initialize(site)
        @options = Selenium::WebDriver::Firefox::Options.new
        @d = Selenium::WebDriver.for :remote, url: 'http://localhost:4444', options: @options

        @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
        @d.manage.timeouts.implicit_wait = 30
        @d.manage.delete_all_cookies
        @d.get(site)
    end
    def click(css)
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
    def find(css)
        @wait.until {@d.find_element(:css,css)}
        return @d.find_element(:css,css)
    end
    def quit 
        @d.quit
    end
end


puts "Starting.. User is #{user}"
begin

    dl = Driver.new('https://clubs.thefa.com')
    puts "Loaded first page, waiting for cookie pop-up"
    begin
        dl.click('#onetrust-accept-btn-handler')
    rescue Selenium::WebDriver::Error
    end

    sleep 1


    puts "Waiting to sign in"

    dl.send('#signInName',user)
    dl.send('#password',pass)
    sleep 0.1
    dl.click('html body div#panel.panel table.panel_layout tbody tr.panel_layout_row td#panel_center div.inner_container div.api_container.normaltext div#api form#localAccountForm.localAccount div.entry div.buttons button#next')
    puts "Signing in.."
    sleep 10

    doc = dl.click('div.cursor-pointer:nth-child(2) > span:nth-child(1)')
    raise "Unexpected text on My Club button: #{doc.text}" unless doc.text == "Documentation"

    file = dl.find('div.table-row:nth-child(1) > div:nth-child(1) > div:nth-child(2)')
    puts "Filename = #{file.text}"

    dl.click('div.table-row:nth-child(1) > div:nth-child(4) > div:nth-child(1) > img:nth-child(1)')

    puts "waiting for download"

    sleep 30
ensure

dl.quit

end