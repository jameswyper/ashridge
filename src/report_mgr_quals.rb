require 'rubyXL'
require 'rubyXL/convenience_methods'
require 'optparse'
require 'csv'

GREEN = '00FF80'
AMBER = 'FF9933'
RED = 'FF3333'

$asof = Date.today
class Role
    attr_accessor :role,:dbs
    def initialize(name,dbsreq,seq)
        @role = name
        @dbs = dbsreq
        @seq = seq
    end
    def self.boot
        @@roles = Hash.new
        [["Manager",true,0],["Admin",false,10],["A1",true,1],["A2",true,2],["A3",true,3],["A4",true,4],["A5",true,5]].each do |p|
            @@roles[p[0]] = Role.new(p[0],p[1],p[2])
        end
    end
    def self.byRole
        @@roles
    end
end

class Person
    attr_reader :name, :email, :mobile, :fan, :team, :role, :dbs, :dbsdate, :sg, :sgdate, :fa, :fadate
    def initialize(n,e,m,f,t,r)
        @name = n
        @email = e
        @mobile = m
        @fan = f.to_i
        @team = t
        @role = r
        @@byTeam[t] = (@@byTeam[t] || Array.new).append(self)
        @@byFan[f] = self
    end
    def self.boot
        @@byTeam = Hash.new
        @@byFan = Hash.new
    end

    def self.byTeam
        @@byTeam
    end
    def self.byFan
        @@byFan
    end 
end

class Team
    attr_accessor :name, :open, :girls, :suffix, :age, :fee, :trainingDay, :trainingTime, :trainingVenue, :ar
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
                r[10] ? r[10].value : "", r[11] ? r[11].value : "", r[12] ? r[12].value : "", r[13] ? r[13].value : "" )
            rc = rc + 1
        end
    end
    def initialize(n,s,o,g,a,td,tt,tv,ar,fee)
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
        @@teams[n] = self
    end
    def self.byTeam
        @@teams
    end
end

class QualRec
    attr_accessor :teams
    attr_reader :fan, :name, :teamName, :teamAge,  :role, :dbsExpiry, :faExpiry, :sgExpiry, :dbsStatus, :sgStatus, :faStatus, :qual, :teams
    def initialize(ta,tn,yt,at,r,f,n,q,fa,sg,dbs)
        @fan = f.to_i
        @name = n
        @teamName = tn
        @teams = [tn]
        @teamAge = ta
        #@teamStatusYouth = yt
        #@teamStatusAdult = at
        @role = r
        @qual = q

        if dbs == "Not Held" 
            @dbsStatus = false
        else
            if dbs == "Expired" || dbs == "In Progress"
                @dbsStatus = false
            else
                @dbsStatus = true
                if dbs.start_with?("Expiring")
                    @dbsExpiry = Date.parse(dbs[10..19])
                else
                    @dbsExpiry = Date.parse(dbs)
                end
            end
        end

        if sg == "Not Held" 
            @sgStatus = false
        else
            if sg == "Expired"
                @sgStatus = false
            else
                @sgStatus = true
                if sg.start_with?("Expiring")
                    @sgExpiry = Date.parse(sg[10..19])
                else
                    @sgExpiry = Date.parse(sg)
                end
            end
        end

        if fa == "Not Held" 
            @faStatus = false
        else
            if fa == "Expired"
                @faStatus = false
            else
                @faStatus = true
                if fa.start_with?("Expiring")
                    @faExpiry = Date.parse(fa[10..19])
                else
                    @faExpiry = Date.parse(fa)
                end
            end
        end
    end



    def self.boot(f)
        @@quals = Hash.new
        
        w = RubyXL::Parser.parse(f)
        s = w[0]
        rc = 9
        raise "Unknown Spreadsheet format" unless s[rc][0].value == "Team Age"
        rc = rc + 1
        
        while s[rc] && s[rc][0] && s[rc][0].value != "" do
            r = s[rc]
            fan = r[5].value.to_i
            if @@quals[fan]
                @@quals[fan].teams << r[1].value
            else
                t = QualRec.new(
                    r[0].value == "Open?" ? 99 : r[0].value[1..-1].to_i,
                    r[1].value,r[2].value,r[3].value,r[4].value,r[5].value,r[6].value,r[7].value,r[8].value,r[9].value,r[10].value)
                @@quals[fan] = t    
            end
            rc = rc + 1

        end
        
        
=begin        
        s = CSV.parse(File.read(f))
        rc = 1
        while (rc < s.length) do
            r = s[rc]
            fan = r[0]
            if @@quals[fan]
                @@quals[fan].teams << r[3]
            else
               q = QualRec.new(fan,r[1],r[2],r[3],r[6],r[7],r[8],r[9])
               @@quals[fan.to_i] = q
            end
            rc = rc + 1
        end
=end
    end
    def self.qualsFor
        @@quals
    end
    def self.checkRedundant(f)
        w = RubyXL::Workbook.new
        s = w[0]
        rc = 1
        @@quals.each_value do |q|
            unless Person.byFan[q.fan.to_i]
                q.teams.each_index do |i|
                    s.add_cell(rc,0,q.name)
                    s.add_cell(rc,1,q.teams[i])
                    rc = rc + 1
                end
            end
        end
        w.write(f)
    end
end

class Contacts
    def initialize(f)
        @contacts = Array.new
        w = RubyXL::Parser.parse(f)
        s = w[0]
        rc = 1
        while s[rc] && s[rc][0] && s[rc][0] != "" do
            r = s[rc]
            p = Person.new(r[2].value,r[3].value,r[4] ? r[4].value : "",r[5] ? r[5].value : "",Team.byTeam[r[0].value],Role.byRole[r[1].value])
            @contacts.append(p)
            rc = rc + 1
        end
    end
    def create_formatted(f)
        
        w = RubyXL::Workbook.new
        s = w[0]
        s.sheet_name = "Contacts"
        
        c = 0
        ['Team','Training Day', 'Training Time', 'Winter Venue', 'AR?','Fees','Manager','Manager email', 'Manager Phone','Assistant 1','Asst 1 email','Assistant 2','Asst 2 email','Assistant 3','Asst 3 email',
        'Admin','Admin email'].each do |h|
            s.add_cell(0,c,h)
            c = c + 1
        end
        [0,1,2,3,8].each {|c| s.change_column_width(c,15)}
        [6,9,11,13,15].each {|c| s.change_column_width(c,20)}    
        [7,10,12,14,16].each {|c| s.change_column_width(c,25)} 
        s.sheet_data[0][0..16].each {|c| c.change_font_bold(true)}   
        rc = 1
        ts = Team.byTeam.values.sort_by { |t| [t.open ? 1 : 0,t.girls ? 1 : 0,t.age,t.suffix]}
        ts.each do |t|

            ps = Person.byTeam[t]
            if ps
                m = ps.select { |p| p.role.role == "Manager" }[0]
           
                s.add_cell(rc,0,t.name)

                s.add_cell(rc,1,t.trainingDay)
                s.add_cell(rc,2,t.trainingTime)
                s.add_cell(rc,3,t.trainingVenue)
                s.add_cell(rc,4,t.ar)
                s.add_cell(rc,5,t.fee)

                s.add_cell(rc,6,m.name)
                s.add_cell(rc,7,m.email)
                s.add_cell(rc,8,m.mobile)
                cc = 9
                ["A1","A2","A3","Admin"].each do |r|
                    p = ps.select { |p| p.role.role == r }
                    unless p.empty?
                        s.add_cell(rc,cc,p[0].name)
                        s.add_cell(rc,cc+1,p[0].email)
                    end
                    cc = cc + 2
                end
                rc = rc + 1
           else
                puts "Team #{t.name} not found on contacts sheet"            
           end
        end
        w.write(f)
        return w
    end

    def create_qualcheck(contacts,f)
        w = RubyXL::Workbook.new
        s = w[0]
        s.sheet_name = "Qualifications"
        
        rc = 1
        ts = Team.byTeam.values.sort_by { |t| [t.open ? 1 : 0,t.girls ? 1 : 0,t.age,t.suffix]}
        ts.each do |t|
            ti = Array.new
            ps = Person.byTeam[t]

            if ps
                faCt = 0
                ps.select{|p| p.role.role != "Admin"}.each do |p|
                    i = Array.new
                    if p.fan <= 0 
                        i << [1,"No FAN"]
                    else
                        q = QualRec.qualsFor[p.fan]
                        if q
                            unless t.open
                                unless (q.dbsExpiry) && (q.dbsExpiry > $asof)
                                    i << [1, "No in-date DBS"]       
                                else
                                    if q.dbsExpiry < ($asof + 90)
                                        i << [2,"DBS expiring soon"]
                                    end
                                end
                                unless (q.sgExpiry) && (q.sgExpiry > $asof)
                                    i << [1, "No in-date Safeguarding"]       
                                else
                                    if q.sgExpiry < ($asof + 60)
                                        i << [2,"Safeguarding expiring soon"]
                                    end
                                end
                            end
                            if q.faExpiry
                                if q.faExpiry >= $asof
                                    faCt = faCt + 1
                                end
                                if q.faExpiry < $asof 
                                    i << [1, "First Aid expired"]
                                else
                                    if q.faExpiry < $asof + 60
                                        i << [2,"First Aid expiring soon"]
                                    end
                                end
                            end
                        else
                            i << [1,"Not on Wholegame (probably no DBS)"]
                        end
                    end
                    unless i.empty?
                        ti << [p.name,i]
                    end
                end
                rs = rc    
                s.add_cell(rc,0,t.name)
                teamStatus = "G"
                
                faMsg = "First Aid OK"
                if (faCt == 0)
                    teamStatus = "R"
                    faMsg = "No Qualified First Aiders"
                else
                    if faCt < 2
                    #    teamStatus = "A"
                        #   faMsg = "Only one Qualifed First Aider"
                    end
                end
                s.add_cell(rc,1,faMsg)
                if teamStatus == "R"
                    s.sheet_data[rc][1].change_fill(RED)
                else
                    s.sheet_data[rc][1].change_fill(GREEN)
                end
                if ti.empty?
                    s.add_cell(rc,2,"All DBS/SG OK")
                    s.sheet_data[rc][2].change_fill(GREEN)
                    rc = rc + 1
                else
                    ti.each do |tm|
                        tm[1].each do |i|
                            s.add_cell(rc,2,"#{tm[0]} - #{i[1]}")
                            if i[0] == 1 
                                teamStatus = "R"
                                s.sheet_data[rc][2].change_fill(RED)
                            else
                                if i[0] == 2 && teamStatus == "G"
                                    teamStatus = "A"
                                end
                                s.sheet_data[rc][2].change_fill(AMBER)
                            end
                            rc = rc + 1
                        end
                    end
                end
                (rs..rs).each do |r|
                    unless s[r][0]
                        s.add_cell(r,0,"")
                    end
                    s.sheet_data[r][0].change_fill(teamStatus == "G" ? GREEN : (teamStatus == "A" ? AMBER : RED )) 
                end
            else
                puts "Team #{t.name} not found on contacts sheet again"
            end

        end # of team iterator
        
        s.add_cell(0,0,"Team")
        s.add_cell(0,1,"First Aid Status")
        s.add_cell(0,2,"Other issues")
        s.sheet_data[0][0..2].each {|c| c.change_font_bold(true)}
        s.change_column_width(0,25)
        s.change_column_width(1,25)
        s.change_column_width(2,50)



        w.add_worksheet("Team Roles")
        t = w[1]
        r = contacts[0]
        l = 0
        while r[l] do
             l = l + 1
        end
        [[0,0],[1,6],[2,9],[3,11],[4,13],[5,15]].each do |p|

            (0..l).each do |i|
                if r.sheet_data[i] && r.sheet_data[i][p[1]]
                    t.add_cell(i, p[0], r.sheet_data[i][p[1]].value)
                end
            end
            t[0][p[0]].change_font_bold(true)
            t.change_column_width(p[0],25)
        end

        

        w.write(f)
    end

end

f = ARGV[1]

Role.boot
Person.boot
Team.boot(f)
QualRec.boot(ARGV[0])


c = Contacts.new(f)
#should check person's team against teams array when loading

contacts = c.create_formatted("/home/james/data/contact_publish.xlsx")
c.create_qualcheck(contacts, "/home/james/data/quals_publish.xlsx")
QualRec.checkRedundant("/home/james/data/for_removal.xlsx")