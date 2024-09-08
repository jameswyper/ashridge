require 'rubyXL'
require 'rubyXL/convenience_methods'
require 'sqlite3'

class ExcelToSQLite
  
  def initialize(xls,db,table,sheet,hdr = 1)
    db = SQLite3::Database.new(db)
    w = RubyXL::Parser.parse(xls)
    s = w[sheet]
    hrow = s[hdr-1]
    c = 0
    tabcols = Array.new
    while (hrow[c]) do
      tabcols << hrow[c].value
      c = c + 1
    end
    cols = c    
    collist = "(" + tabcols.collect{|x| '"' + x + '"'}.join(",") + ")"
    qlist = "(" + tabcols.collect {|x| "?"}.join(",") + ")"
    dropstmt = "drop table if exists " + table + ";"
    crstmt =  "create table " + table + " " + collist + ";"
    db.execute(dropstmt)
    db.execute(crstmt)
    db.transaction
    rr = hdr
    while (s[rr]) do
      row = Array.new
      for c in 0..(cols-1) do
        row << if (s[rr][c] && s[rr][c].value) 
                  v = s[rr][c].value
                  if v.kind_of?(Integer)
                    v
                  else
                    if v.kind_of?(DateTime)
                      "'" + v.strftime('%Y-%m-%d') + "'"
                    else  
                      "'" + v + "'"
                    end
                  end
              else 
                  nil 
              end
          end
      stmt = "insert into " + table + " " + collist + " values " + qlist + ";"

      db.execute(stmt, row)
      
      rr = rr + 1
    end
    db.commit
  end
end

class SQLiteToExcel
  attr_reader :namemap
  def initialize(xls,sheet,db)
    
    #bug means we can't add to existing workbooks
    #if File.exist? xls
    #   @xl = RubyXL::Workbook.parse(xls)
    #   @s = @xl.add_worksheet(sheet)
    #else
    
      @xl = RubyXL::Workbook.new
      @s = @xl['Sheet1']
      @s.sheet_name = sheet
    #end
    @db = SQLite3::Database.new(db)
    @xlsfile = xls


    @row = 0
    @colnames = Array.new
    @namemap = Hash.new
  end
  
  def add_narrative(n)
    @s.add_cell(@row,0,"Produced on #{Time.now.strftime("%d/%m/%Y %H:%M")}")
    @row = @row + 1
    n.each do |l|
      @s.add_cell(@row,0,l)
      @row = @row + 1
    end
  end
  

  def run_query(q,namemap)
    @namemap = namemap
    res = @db.query(q)
    res.columns.each do |c|
      @colnames << (namemap[c] || c)
    end
    @row = @row + 1

    col = 0
    @colnames.each do |c| 
      @s.add_cell(@row,col,c)
      col = col + 1
    end
    @row = @row + 1
    @firstrow = @row
    res.each do |row|
      col = 0
      row.each do |v|
        @s.add_cell(@row,col,v)
        col = col + 1
      end
      @row = @row + 1
    end
    @lastrow = @row - 1
  end
  
  def find_column(col)
    return @colnames.find_index(@namemap[col] || col)
  end

  def format_column(col)
    c = find_column(col)
    for r in @firstrow..@lastrow do
      @s[r][c].change_fill (yield(@s[r][c].value) || WHITE)
    end

  end
  
  def ynrg(col)
    format_column(col) {|s| if s == "Y" then GREEN else RED end}
  end

  def mask_column(col)
    c = find_column(col)
    for r in @firstrow..@lastrow do
      @s[r][c].change_contents(yield(@s[r][c].value) )
    end

  end
  def set_widths(w)
    w.each_index {|i| @s.change_column_width(i, w[i])}
  end

  def save
    worksheetview = RubyXL::WorksheetView.new
    worksheetview.pane = RubyXL::Pane.new(:top_left_cell => RubyXL::Reference.new(0,@firstrow), :x_split => 0, :y_split => @firstrow, :state => 'frozen')
    worksheetviews = RubyXL::WorksheetViews.new
    worksheetviews << worksheetview
    @s.sheet_views = worksheetviews
    @xl.write(@xlsfile)
  end

end