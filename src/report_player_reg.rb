require 'net/http'
require 'nokogiri'
require 'rubyXL'
require 'rubyXL/convenience_methods'
require 'optparse'
require 'netrc'

#puts ARGV.to_s

if OpenSSL::SSL.const_defined?(:OP_IGNORE_UNEXPECTED_EOF)
    OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gfdownload.rb [options]"

  opts.on("-u", "--user USER",  "GotFootball user ID") do |u|
    options[:user] = u
  end

  opts.on("-p", "--pass PASS", "GotFootball password") do |p|
    options[:pass] = p
  end

  opts.on("-e", "--ebfa EBFA", "GotFootball EBFA event id (4408 for 2021/22)") do |e|
    options[:ebfa] = e
  end

  opts.on("-c", "--club [CLUB]", "Club Program IDs (comma separated e.g. 4193,4197)") do |c|
    if c
      options[:club] = c.split(",")
    else
      options[:club] = []
    end
  end

  opts.on("-w", "--wgxls WG", "Path to Wholegame Player Download - enclose in quotes if the path contains spaces") do |w|
    options[:wgxls] = w
  end

  
  opts.on("-t", "--team TEAM", "Path to Manager contact MASTER spreadsheet - enclose in quotes if the path contains spaces") do |t|
    options[:team] = t
  end

  opts.on("-o", "--output OUT", "Path to output spreadsheet - enclose in quotes if the path contains spaces") do |o|
    options[:outxls] = o
  end
  
  opts.on("-s", "--summary OUT", "Path to summary output spreadsheet - enclose in quotes if the path contains spaces") do |s|
    options[:sumxls] = s
  end


end.parse!

nuser,npass = Netrc.read["gotfootball.co.uk"]

#puts "netrc user is #{nuser} and commandline user is #{options[:user]}"
if options[:user].nil? then gfuser = nuser else gfuser = options[:user] end
if options[:pass].nil? then gfpass = npass else gfpass = options[:pass] end

wgxlsfile = options[:wgxls]
outxlsfile = options[:outxls]
sumxlsfile = options[:sumxls]
teamfile = options[:team]

class Team
    attr_accessor :name, :open, :girls, :suffix, :age, :fee, :trainingDay, :trainingTime, :trainingVenue, :ar, :seq
    def self.team(t)
        @@teams[t]
    end
    def self.boot(f)
        @@teams = Hash.new
        w = RubyXL::Parser.parse(f)
        s = w[1]
        rc = 1
        while s[rc] && s[rc][7] && s[rc][7].value != "" do
            r = s[rc]
            t = Team.new(r[7].value,r[1] ? r[1].value : "",r[3].value,r[2] ? r[2].value : "", r[0] ? r[0].value : 99, r[9] ? r[9].value : "", 
                r[10] ? r[10].value : "", r[11] ? r[11].value : "", r[12] ? r[12].value : "", r[13] ? r[13].value : "" , rc)
            rc = rc + 1
        end
    end
    def initialize(n,s,o,g,a,td,tt,tv,ar,fee,seq)
        @name = n
        @open = (o.to_i > 0)
        @girls = (g.to_i > 0)
        @suffix = s
        @age = a
        @trainingTime = tt
        @trainingDay = td
        @trainingVenue = tv
        @ar = ar
        @fee = fee
        @seq= seq
        if @name.end_with?(" Park")
            @wgname = "Ashridge Park " + @name[0..-6]
        else
            @wgname = "Ashridge Park " + @name
        end
        @@teams[@wgname.dup] = self        
    end
    def self.byTeam
        @@teams
    end
end

class GFplayer
    attr_accessor :id, :gfid, :fan, :level, :lastname, :firstname, :famacct, :famacctname, :postcode, :dob, :gender, :year, :team, :jersey, :email
end

class WGplayer
    attr_accessor :firstnames, :lastname, :fan, :dob, :agegroup, :gender, :teams, :regstatus, :email, :parentemail, :consent, :parentname, :subdate, :regdate

end

class EBFAreg
    attr_accessor :id, :gfid, :fan, :lastname, :firstname, :dob, :verified, :consent, :photo, :jersey
end

class Clubreg
    attr_accessor :id,  :prog, :complete, :lastname, :firstname
end

# log in and extract session cookie
session = ""
uri = URI('https://www.gotfootball.co.uk/asp/directors/login.asp?mode=&EventID=')
Net::HTTP.start(uri.host,uri.port, :use_ssl => uri.scheme == 'https') do |http|
    lrequest = Net::HTTP::Post.new(uri)
    lrequest.set_form_data('UserName' => gfuser, 'Password' => gfpass)
    lresponse = http.request lrequest
    session = lresponse['Set-Cookie'].gsub('/ path=\//','')
end

# generic scraper function

def scraper(initurl,nextpage,session)
    pages = Array.new
    puri = URI(initurl)
    Net::HTTP.start(puri.host,puri.port, :use_ssl => puri.scheme == 'https') do |http|
        loop do
            #puts "requesting #{puri.to_s}"
            prequest = Net::HTTP::Get.new(puri.to_s)
            prequest['Cookie'] = 'cookieconsent_dismissed=yes; ' + session
            presponse = http.request prequest
            #puts "HTTP code #{presponse.code} from #{puri.to_s}"
            doc = Nokogiri::HTML.parse(presponse.body)
            pages << doc
            nextp = doc.xpath(nextpage)
            unless nextp.length > 0 
                break
            end
            puri = URI(nextp[0][:href])
        end 
    end
    return pages
end

# scrape basic player info

def playerscraper(p,session)
    puri = URI('https://www.gotfootball.co.uk/asp/directors/club/player.asp?rosterid=' + p.gfid)
    Net::HTTP.start(puri.host,puri.port, :use_ssl => puri.scheme == 'https') do |http|

        prequest = Net::HTTP::Get.new(puri.to_s)
        prequest['Cookie'] = 'cookieconsent_dismissed=yes; ' + session
        presponse = http.request prequest
        #puts "HTTP code #{presponse.code} from #{puri.to_s}"
        doc = Nokogiri::HTML.parse(presponse.body)

        p.email = doc.xpath('//input[@name="RosterPlayerEmail"]')[0][:value]
        
    end
end

gfplayers = Array.new
pages = scraper('https://www.gotfootball.co.uk/asp/directors/club/players.asp?PageSize=250&Photos=NO&ShowTeams=NO&RegistrationCompetitionLevel=&PlayersRostered=&RosterFlag=&FilterProgramID=&EventID=&filterPlayerAge=&filterPlayerAgeLimit=&RosterPlayerSex=&PlayerRating=&PlayerName=&PlayerIDNumber=&FamilyID=&TeamName=&PlayerEmail=&ParentName=&ParentEmail=&SchoolGrade=&DocsUploaded=&BirthCert=&BirthCertForeign=&IntlClearance=&SetLevelSelect=&SetTeamIDSelect=&SetFlag=&ProgramID=','//div[@id="nodrop"]/table/tr/td[1]/table//tr[2]/td[3]/font/a',session)

pages.each do |page|
    playerRows = page.xpath('//div[@id="nodrop"]/table/tr/td[1]/form/table[2]/tr')
    playerRows[1..-1].each do |playerRow|
        playerCols = Nokogiri::HTML.parse(playerRow.to_s).xpath('//td')
        p = GFplayer.new
        p.id = playerCols[2].text
        gfid = Nokogiri::HTML.parse(playerCols[2].to_s).xpath('//a')
        gflink = gfid[0][:href]
        p.gfid = gflink.match(/.*=(.*)/).captures[0]

        p.fan = playerCols[3].text
        p.level = playerCols[4].text
        name = playerCols[5].text
        p.firstname = name.split(', ')[1]
        p.lastname = name.split(', ')[0][2..-1]
        p.famacct = playerCols[6].text
        p.famacctname = playerCols[7].text
        p.postcode = playerCols[10].text
        p.dob = playerCols[11].text[0..9]
        p.gender = playerCols[12].text
        p.year = playerCols[14].text
        p.team = playerCols[15].text
        p.jersey = playerCols[16].text
        if (p.id.end_with? "*")
            #puts "Trimmed #{p.inspect}"
            p.id = p.id[0..-2] 
        end

        gfplayers << p
    end
end

# scrape EBFA registrations

ebfaregplayers = Array.new
pages = scraper('https://www.gotfootball.co.uk/asp/directors/club/players.asp?PageSize=250&Photos=YES&ShowTeams=NO&RegistrationCompetitionLevel=&PlayersRostered=&RosterFlag=&FilterProgramID=&EventID=' + options[:ebfa] + '&filterPlayerAge=&filterPlayerAgeLimit=&RosterPlayerSex=&PlayerRating=&PlayerName=&PlayerIDNumber=&FamilyID=&TeamName=&PlayerEmail=&ParentName=&ParentEmail=&SchoolGrade=&DocsUploaded=&BirthCert=&BirthCertForeign=&IntlClearance=&SetLevelSelect=&SetTeamIDSelect=&SetFlag=&ProgramID=','//div[@id="nodrop"]/table/tr/td[1]/table/tr[2]/td[3]/font/a',session)

pages.each do |page|
    playerRows = page.xpath('//div[@id="nodrop"]/table/tr/td[1]/form/table[2]/tr')
    playerRows[1..-1].each do |playerRow|
        playerCols = Nokogiri::HTML.parse(playerRow.to_s).xpath('//td')
        p = EBFAreg.new

        #attr_accessor :id, :gfid, :fan, :lastname, :firstname, :dob, :verified, :consent, :photo, :jersey

        plink = Nokogiri::HTML.parse(playerCols[1].to_s).xpath('//img') 
        p.photo = (plink.length > 0)
    
        p.id = playerCols[3].text

        gfid = Nokogiri::HTML.parse(playerCols[3].to_s).xpath('//a')
        gflink = gfid[0][:href]
        p.gfid = gflink.match(/.*=(.*)/).captures[0]

        p.fan = playerCols[4].text
        name = playerCols[6].text
        p.firstname = name.split(', ')[1]
        p.lastname = name.split(', ')[0][2..-1]
        p.dob = playerCols[12].text[0..9]
        p.verified = (playerCols[12].text[11..13] == "(V)")
        #puts playerCols[12].text[11..13]
        #puts playerCols[21].text
        p.consent = (playerCols[21].text == "&check;")
        #p.gender = playerCols[13].text
        #p.year = playerCols[15].text
        #p.team = playerCols[16].text
        p.jersey = playerCols[17].text
        ebfaregplayers << p
    end
end


ebfaregbygfid = Hash.new
ebfaregplayers.each {|p| ebfaregbygfid[p.gfid] = p}

# scrape Club registrations

clubregplayers = Array.new
pages = []
options[:club].each do |prog|
    pages = pages + scraper('https://www.gotfootball.co.uk/asp/directors/club/extended/registrations.asp?SearchFiltersVis_Opt=&SearchFormFiltersVis_Opt=&SearchMode=SIMPLE&ProgramID='+ prog + '&ShowColumn=PaymentPlan&RosterFlag=&PageSize=100&Photos=NO&status=&pmtmethod=&pmtstatus=&CourseCompleted=&AgreementSigned=&PlayersRostered=&ExProgramID=&PaymentPlanID=&WaitListed=&BirthCert=&ClubOfferID=&PlayerName=&SearchRegistrationID=&RegisteredFrom=&RegisteredTo=&RegistrationPapers=&RegistrationCompetitionLevel=&PlayerRating=&SchoolGrade=&RosterPlayerSex=&filterPlayerAge=&filterPlayerAgeLimit=&PlayerBirthYear=&FilterTeamID=&TeamName=&AdvancedFilters=Apply+Filters','//div[@id="nodrop"]/table/tr/td[1]/table/tr[2]/td[3]/font/a',session)
end

pages.each do |page|
  
    progopts = page.xpath('//select[@name="ProgramID"]/optgroup/option')
    
    prog = progopts.select{|po| po[:selected] == "selected" }[0][:value]

    playerRows = page.xpath('//div[@id="nodrop"]/table/tr/td[1]/form/table[2]/tr')
    playerRows[1..-1].each do |playerRow|
        playerCols = Nokogiri::HTML.parse(playerRow.to_s).xpath('//td')
        p = Clubreg.new
        #attr_accessor :id, :gfid, :prog, :complete

        p.prog = prog
        p.id = playerCols[1].text

        name = playerCols[3].text
        p.firstname = name.split(', ')[1]
        p.lastname = name.split(', ')[0][2..-1]
       # gfid = Nokogiri::HTML.parse(playerCols[1].to_s).xpath('//a')
       # gflink = gfid[0][:href]
       # p.gfid = gflink.match(/.*=(.*)/).captures[0]
        
        p.complete = (playerCols[14].text[1..8] == "Complete")
        clubregplayers << p
    end
end

clubregbyid = Hash.new
clubregplayers.each {|p| clubregbyid[p.id] = p}
# open Wholegame spreadsheet

wgplayers = Array.new

wgxls = RubyXL::Parser.parse(wgxlsfile)
wgws = wgxls[0]
lastfan = 0
rnum = 7
lastplayer = nil
loop do 
    row = wgws[rnum]
    thisfan = row[2].value
    #puts row[0].value
    if (thisfan == lastfan)
        if row[7]
            unless wgplayers[-1].teams.include? row[7].value.strip
                wgplayers[-1].teams << row[7].value.strip
            end
        end
    else
        p = WGplayer.new
        p.teams = row[7] ? [row[7].value.strip] : Array.new
        p.fan = thisfan
        p.firstnames = row[0].value
        p.lastname = row[1].value
        p.dob = row[3].value ? row[3].value.strftime('%d/%m/%Y') : ""
        p.agegroup = row[4].value
        p.gender = row[5] ? row[5].value[0] : ""
        p.regstatus = row[11] ? row[11].value : ""
        p.email = row[12]? row[12].value : ""
        p.parentemail = row[14] ? row[14].value : ""
        p.consent=row[18] ? row[18].value : ""
        p.parentname = row[13] ? row[13].value : ""
        p.subdate = row[8] ? row[8].value : ""
        p.regdate = row[9] ? row[9].value : ""
        lastfan = thisfan
        wgplayers << p
    end 
    #puts "row #{rnum} processed"
    rnum = rnum + 1

    unless wgws[rnum]
        break
    end

end

wgbyfan = Hash.new
wgbynamedob = Hash.new
wgplayers.each do |p| 
    unless wgbyfan[p.fan.to_s] then wgbyfan[p.fan.to_s] = p end
    unless wgbynamedob[[p.lastname.downcase,p.dob]] then wgbynamedob[[p.lastname.downcase,p.dob]] = p end
end

Team.boot(teamfile)

class Report

    def initialize(file,summary)
        @file = file
        @w = RubyXL::Workbook.new
        @summary = summary
        
        unless @summary
            @w[0].sheet_name = 'Add fan to GF'
            @addfan = @w[0]
            @w.add_worksheet('Fix fan on GF')
            @fixfan = @w[1]
            @w.add_worksheet('Not on WG')
            @notonwg = @w[2]
            @w.add_worksheet('Fix team on WG')
            @fixteam = @w[3]
            @w.add_worksheet('Fix DOB on WG')
            @fixdob = @w[4]
            @w.add_worksheet('Submit to League on WG')
            @tosubmit = @w[5]
            @w.add_worksheet('Registration Progress')
            @progress = @w[6]
        else
            @w[0].sheet_name = 'Registration Progress'
            @progress = @w[0]
        end

        unless @summary
            @w.add_worksheet('Email Capture')
            @ecap = @w[7]
            @w.add_worksheet('Potentially unwanted players on Wholegame')
            @wgclean = @w[8]
        end

        unless @summary
            @addfan.add_cell(0,0,"FANs to add to GotFootball")
            @addfan.add_cell(1,0,"Lastname")
            @addfan.add_cell(1,1,"Firstname")
            @addfan.add_cell(1,2,"EBFA ID")
            @addfan.add_cell(1,3,"FAN")
            @rnum_addfan = 2

            @fixfan.add_cell(0,0,"FANs to change on GotFootball (or to add to Wholegame if WG FAN blank)")
            @fixfan.add_cell(1,0,"Lastname")
            @fixfan.add_cell(1,1,"Firstname")
            @fixfan.add_cell(1,2,"EBFA ID")
            @fixfan.add_cell(1,3,"WG FAN")
            @fixfan.add_cell(1,4,"FAN on GF")
            @fixfan.add_cell(1,5,"DOB on GF")
            @fixfan.add_cell(1,6,"Team on GF")
            @rnum_fixfan = 2

            @notonwg.add_cell(0,0,"Players To add to Wholegame (either don't exist or not attached to club yet)")
            @notonwg.add_cell(1,0,"Lastname")
            @notonwg.add_cell(1,1,"Firstname")
            @notonwg.add_cell(1,2,"EBFA ID")
            @notonwg.add_cell(1,3,"DOB")
            @notonwg.add_cell(1,4,"Gender")
            @notonwg.add_cell(1,5,"Postcode")
            @notonwg.add_cell(1,6,"Team")
            #@notonwg.add_cell(1,5,"Parent Email")
            @rnum_notonwg = 2

            @fixteam.add_cell(0,0,"Players with the wrong team on Wholegame (assuming GotFootball is correct)")
            @fixteam.add_cell(1,0,"Lastname")
            @fixteam.add_cell(1,1,"Firstname")
            @fixteam.add_cell(1,2,"EBFA ID")
            @fixteam.add_cell(1,3,"FAN")
            @fixteam.add_cell(1,4,"DOB")
            @fixteam.add_cell(1,5,"Old Team")
            @fixteam.add_cell(1,6,"Correct Team")
            @rnum_fixteam = 2


            @fixdob.add_cell(0,0,"Fix Name and/or DOB (probably on Wholegame) as they differ between the two systems")
            @fixdob.add_cell(1,0,"GF Lastname")
            @fixdob.add_cell(1,1,"GF Firstname")
            @fixdob.add_cell(1,2,"WG Lastname")
            @fixdob.add_cell(1,3,"WG Firstname")
            @fixdob.add_cell(1,4,"EBFA ID")
            @fixdob.add_cell(1,5,"FAN")
            @fixdob.add_cell(1,6,"GF DOB")
            @fixdob.add_cell(1,7,"WG DOB")
            @rnum_fixdob = 2

            @tosubmit.add_cell(0,0,"Players with ID verified and Consent in GotFootball - ready to verify and offline consent in Wholegame (and then submit)")
            @tosubmit.add_cell(1,0,"GF Lastname")
            @tosubmit.add_cell(1,1,"GF Firstname")
            @tosubmit.add_cell(1,2,"DOB")
            @tosubmit.add_cell(1,3,"FAN")
            @tosubmit.add_cell(1,4,"Team")
            @tosubmit.add_cell(1,5,"Parent email on WG")        
            @tosubmit.add_cell(1,6,"Player email on WG")        
            @tosubmit.add_cell(1,7,"Which email reqd")        
            @tosubmit.add_cell(1,8,"Submitted (on WG) date")        
            @tosubmit.add_cell(1,9,"Parent email on GF")
            @tosubmit.add_cell(1,10,"WG Consent")        
            @rnum_tosubmit = 2


            @ecap.add_cell(0,0,"Email Capture - what to populate the WG page with")
            @ecap.add_cell(1,0,"Last name")
            @ecap.add_cell(1,1,"First name")
            @ecap.add_cell(1,2,"FAN")
            @ecap.add_cell(1,3,"Email")
            @rnum_ecap = 2

            
            @wgclean.add_cell(0,0,"Wholegame Cleanup? Players on Wholegame but not on a GotFootball Team")
            @wgclean.add_cell(1,0,"Last name")
            @wgclean.add_cell(1,1,"First name")
            @wgclean.add_cell(1,2,"WG DOB")
            @wgclean.add_cell(1,3,"FAN")
            @wgclean.add_cell(1,4,"WG Team")
            @wgclean.add_cell(1,5,"GF Team")
            @rnum_wgclean = 2
        end

        @progress.add_cell(0,0,"GotFootball Registration Status")

        @progress.add_cell(2,0,"Club? [Column D] - has Club Registration been done (paid subs)")
        @progress.add_cell(3,0,"Photo? [Column E, EBFA only] - has a photo been uploaded")
        @progress.add_cell(4,0,"Docs? [Column F, EBFA only] - has proof of age/nationality been uploaded")
        @progress.add_cell(5,0,"GF Consent? [Column G, EBFA only] - has 'Guardian Consent' been completed")
        @progress.add_cell(6,0,"Comment [Column H, EBFA only] - used to record registration problems")
        @progress.add_cell(7,0,"Player Email? [Column I] - Player is over 16; we need their email address on Wholegame (send it along with player & team to James)")
        @progress.add_cell(8,0,"Parent Email? [Column J] - Player is under 16; we need a parent FAN linked to theirs (send player & team, parent FAN and DOB to James)")

        @progress.add_cell(10,0,"Age")
        @progress.add_cell(10,1,"Team")
        @progress.add_cell(10,2,"Name")
        @progress.add_cell(10,3,"Club?")
        @progress.add_cell(10,4,"Photo?")
        @progress.add_cell(10,5,"Docs?")
        @progress.add_cell(10,6,"GF Consent?")
        @progress.add_cell(10,7,"Comment")
        @progress.add_cell(10,8,"Player email present on WG?")
        @progress.add_cell(10,9,"Parent email present on WG?")
        @progress.add_cell(10,10,"WG Consent?")
        @progress.add_cell(10,11,"FAN from GF")
        @rnum_progress = 12

    end

    def save
        @w.write(@file)
    end
    
    def wgcleanup(p,wgp)
        @wgclean.add_cell(@rnum_wgclean,0,wgp.lastname)
        @wgclean.add_cell(@rnum_wgclean,1,wgp.firstnames)
        @wgclean.add_cell(@rnum_wgclean,2,wgp.dob)
        @wgclean.add_cell(@rnum_wgclean,3,wgp.fan)
        @wgclean.add_cell(@rnum_wgclean,4,wgp.teams.join(":"))
        @wgclean.add_cell(@rnum_wgclean,5,p ? p.team : "")
        @rnum_wgclean += 1
    end

    def emailcapture(p,wgp)
        @ecap.add_cell(@rnum_ecap,0,p.lastname)
        @ecap.add_cell(@rnum_ecap,1,p.firstname)
        @ecap.add_cell(@rnum_ecap,2,wgp.fan)
        @ecap.add_cell(@rnum_ecap,3,p.email)
        @rnum_ecap += 1
    end

    def fanmissing(p,wgp)
        @addfan.add_cell(@rnum_addfan,0,p.lastname)
        @addfan.add_cell(@rnum_addfan,1,p.firstname)
        @addfan.add_cell(@rnum_addfan,2,p.id)
        @addfan.add_cell(@rnum_addfan,3,wgp.fan)
        @rnum_addfan += 1
    end
    
    def fandiff(p,wgp)
        @fixfan.add_cell(@rnum_fixfan,0,p.lastname)
        @fixfan.add_cell(@rnum_fixfan,1,p.firstname)
        @fixfan.add_cell(@rnum_fixfan,2,p.id)
        @fixfan.add_cell(@rnum_fixfan,4,p.fan)
        @fixfan.add_cell(@rnum_fixfan,3,wgp ? wgp.fan : "")
        @fixfan.add_cell(@rnum_fixfan,5,p.dob)
        @fixfan.add_cell(@rnum_fixfan,6,p.team)  
        @rnum_fixfan += 1
    end
    
    def wgmissing(p,wgp)
        @notonwg.add_cell(@rnum_notonwg,0,p.lastname)
        @notonwg.add_cell(@rnum_notonwg,1,p.firstname)
        @notonwg.add_cell(@rnum_notonwg,2,p.id)
        @notonwg.add_cell(@rnum_notonwg,3,p.dob)
        @notonwg.add_cell(@rnum_notonwg,4,p.gender)        
        @notonwg.add_cell(@rnum_notonwg,5,p.postcode)
        @notonwg.add_cell(@rnum_notonwg,6,p.team)
        #@notonwg.add_cell(@rnum_notonwg,5,p.email)
        @rnum_notonwg += 1
    end
    
    def teamdiff(p,wgp)
        @fixteam.add_cell(@rnum_fixteam,0,p.lastname)
        @fixteam.add_cell(@rnum_fixteam,1,p.firstname)
        @fixteam.add_cell(@rnum_fixteam,2,p.id)
        @fixteam.add_cell(@rnum_fixteam,3,wgp.fan)
        @fixteam.add_cell(@rnum_fixteam,4,p.dob)
        @fixteam.add_cell(@rnum_fixteam,5,wgp.teams.join(","))
        @fixteam.add_cell(@rnum_fixteam,6,p.team)
        @rnum_fixteam += 1
    end

    def dobdiff(p,wgp)
        @fixdob.add_cell(@rnum_fixdob,0,p.lastname)
        @fixdob.add_cell(@rnum_fixdob,1,p.firstname)
        @fixdob.add_cell(@rnum_fixdob,2,wgp.lastname)
        @fixdob.add_cell(@rnum_fixdob,3,wgp.firstnames)        
        @fixdob.add_cell(@rnum_fixdob,4,p.id)
        @fixdob.add_cell(@rnum_fixdob,5,wgp.fan)
        @fixdob.add_cell(@rnum_fixdob,6,p.dob)
        @fixdob.add_cell(@rnum_fixdob,7,wgp.dob)
        @rnum_fixdob += 1
    end

    def cansubmit(p,wgp,erp)
        @tosubmit.add_cell(@rnum_tosubmit,0,p.lastname)
        @tosubmit.add_cell(@rnum_tosubmit,1,p.firstname)
        @tosubmit.add_cell(@rnum_tosubmit,2,p.dob)
        @tosubmit.add_cell(@rnum_tosubmit,3,p.fan)
        @tosubmit.add_cell(@rnum_tosubmit,4,p.team)
        @tosubmit.add_cell(@rnum_tosubmit,5,wgp.parentemail)
        @tosubmit.add_cell(@rnum_tosubmit,6,wgp.email)
        @tosubmit.add_cell(@rnum_tosubmit,7, (Date.parse(p.dob) <= (Date.today << 192)) ? "Player" : "Parent")
        @tosubmit.add_cell(@rnum_tosubmit,8,wgp.subdate)
        @tosubmit.add_cell(@rnum_tosubmit,9,p.email)
        @tosubmit.add_cell(@rnum_tosubmit,10,wgp.consent)

        @rnum_tosubmit += 1
    end

    def regprogress(p)
        p.each_index do |i|
            @progress.add_cell(@rnum_progress,i,p[i])
            if (p[i] == "Yes")
                @progress.sheet_data[@rnum_progress][i].change_fill("32ff00")
            end
            if (p[i] == "No")
                @progress.sheet_data[@rnum_progress][i].change_fill("ff0000")
            end
        end
        @rnum_progress += 1
    end

end

report = Report.new(outxlsfile,false)
summary = Report.new(sumxlsfile,true)


gfplayers.each do |p|
#    puts "Processing #{p.inspect}"
    unless (p.team == "" || p.team.include?('Girls') || ["U19","U20"].include?(p.year))
#        puts "qualifying team"
        if p.fan != ""
            wgp = wgbyfan[p.fan]
            if wgp
                subtoleague = true
                unless (wgp.dob == p.dob) && (wgp.lastname == p.lastname) && (wgp.firstnames = p.firstname)
                    report.dobdiff(p,wgp)
                    subtoleague = false
                    #puts "DOB DOES NOT MATCH #{p.id} #{p.firstname} #{p.lastname} gf:#{p.dob} wg:#{wgp.dob}"
                end
                if (wgp.teams[0] != p.team)
                    report.teamdiff(p,wgp)
                    subtoleague = false
                    #puts "TEAM DOES NOT MATCH gf:#{p.team} wg:#{wgp.teams[0]}"
                end

# get email address from GF for players where parent email is missing
                if (wgp.parentemail == "")
                    playerscraper(p,session)
                    report.emailcapture(p,wgp)
                end

                #find consent, verified
                erp = ebfaregbygfid[p.gfid]
                unless erp
                    puts "No match on EBFA reg found for #{p.inspect}"
                else
                    if (erp.consent) && (erp.verified) && subtoleague
                        report.cansubmit(p,wgp,erp)
                    end
                end



            else
                #puts "FAN DOES NOT MATCH"
                wgp = wgbynamedob[[p.lastname.downcase,p.dob]]
                report.fandiff(p,wgp)
            end
        else
            wgp = wgbynamedob[[p.lastname.downcase,p.dob]]
            if wgp
                report.fanmissing(p,wgp)
                if (wgp.teams.join(',') != p.team)
                    report.teamdiff(p,wgp)
                    #puts "TEAM DOES NOT MATCH gf:#{p.team} wg:#{wgp.teams[0]}"
                else
                    #puts "team matches"
                end
            else
                #puts "name/dob does not match"
                report.wgmissing(p,wgp)
            end
        end
    end
end


regprogress = Array.new
gfplayers.each do |p|
    e = ebfaregbygfid[p.gfid]
    c = clubregbyid[p.id]
    wgp = wgbyfan[p.fan]
    
    playeremailreqd = false
    parentemailreqd = false
    wgconsent = ""
    if (Date.parse(p.dob) <= (Date.today << 192))
        playeremailreqd = true
    else
        parentemailreqd = true      
    end
    if wgp
        if (playeremailreqd && (wgp.email != ""))
            playeremailreqd = false
        end
        if (parentemailreqd && (wgp.parentemail != ""))
            parentemailreqd = false
        end
        wgconsent = wgp.consent
    end


    regprogress << [p.year,
                    p.team, 
                    p.lastname[0] + ("-" * (p.lastname.length - 2)) +  p.lastname[-1] + " / " + p.firstname[0],

                    c ? "Yes" : "No",
                    if p.team.include? "Girls" then "" else e.photo ? "Yes" : "No" end,
                    if p.team.include? "Girls" then "" else e.verified ? "Yes" : "No" end,
                    if p.team.include? "Girls" then "" else e.consent  ? "Yes" : "No" end,
                    e.jersey ? e.jersey : "",
                    if (Date.parse(p.dob) <= (Date.today << 192)) then playeremailreqd ? "No" : "Yes" else "" end,
                    if (Date.parse(p.dob) <= (Date.today << 192))  then "" else parentemailreqd ? "No" : "Yes" end,
                    wgconsent,
                    p.fan
                 ]
end
regprogress.sort! {|p,q| [(Team.byTeam[p[1]] ? Team.byTeam[p[1]].seq : 99),p[1],p[0],p[2]] <=> [(Team.byTeam[q[1]] ? Team.byTeam[q[1]].seq : 99),q[1],q[0],q[2]]}
regprogress.each do |p| 
    if p[1].length > 0 
        report.regprogress(p)
        summary.regprogress(p)
    end
end

gfbyfan = Hash.new
gfbynamedob = Hash.new
gfplayers.each do |p|
    gfbyfan[p.fan.to_s] = p
    gfbynamedob[[p.lastname.downcase,p.dob]] = p
end

wgplayers.each do |wgp|

# find match on GotFootball

    p = gfbyfan[wgp.fan.to_s]
    unless p
        p = gfbynamedob[[wgp.lastname.downcase,wgp.dob]]
    end

    unless (p && p.team == wgp.teams.join("") && wgp.teams.join("") != "") 
        report.wgcleanup(p,wgp)
    end


end


report.save
summary.save