require File.dirname(__FILE__) + '/spec_helper'

describe PgCsv do

  before :each do
    Test.delete_all
    Test.create :a => 1, :b => 2, :c => 3
    Test.create :a => 4, :b => 5, :c => 6
    
    @name = tmp_dir + "1.csv"
    FileUtils.rm(@name) rescue nil

    @sql0 = "select a,b,c from tests order by a asc"    
    @sql = "select a,b,c from tests order by a desc"
  end
  
  after :each do
    FileUtils.rm(@name) rescue nil
  end
  
  describe "simple export" do
  
    it "1" do
      PgCsv.new(:sql => @sql0).export(@name)
      with_file(@name){|d| d.should == "1,2,3\n4,5,6\n" }
    end
    
    it "2" do
      PgCsv.new(:sql => @sql).export(@name)
      with_file(@name){|d| d.should == "4,5,6\n1,2,3\n" }
    end
    
    it "delimiter" do
      PgCsv.new(:sql => @sql).export(@name, :delimiter => "|")
      with_file(@name){|d| d.should == "4|5|6\n1|2|3\n" }
    end
    
    
    describe "headers" do
      it "header" do
        PgCsv.new(:sql => @sql).export(@name, :header => true)
        with_file(@name){|d| d.should == "a,b,c\n4,5,6\n1,2,3\n" }
      end

      it "columns" do
        PgCsv.new(:sql => @sql).export(@name, :columns => %w(q w e))
        with_file(@name){|d| d.should == "q,w,e\n4,5,6\n1,2,3\n" }
      end
      
      it "columns with header" do
        PgCsv.new(:sql => @sql).export(@name, :header => true, :columns => %w(q w e))
                    
        with_file(@name) do |d|
          d.should == "q,w,e\n4,5,6\n1,2,3\n"
        end
      end
    end
    
  end
  
  describe "moving options no matter" do
    it "1" do
      PgCsv.new(:sql => @sql).export(@name, :delimiter => "|")
      with_file(@name){|d| d.should == "4|5|6\n1|2|3\n" }
    end
    
    it "2" do
      PgCsv.new(:delimiter => "|").export(@name, :sql => @sql)
      with_file(@name){|d| d.should == "4|5|6\n1|2|3\n"}
    end
  end
  
  describe "local options dont recover global" do
    it "test" do
      e = PgCsv.new(:sql => @sql, :delimiter => "*")
      e.export(@name, :delimiter => "|")
      with_file(@name){|d| d.should == "4|5|6\n1|2|3\n" }
      
      e.export(@name)
      with_file(@name){|d| d.should == "4*5*6\n1*2*3\n" }
    end
  end
  
  describe "using temp file" do
    it "at least file should return to target" do
      File.exists?(@name).should be_false
      PgCsv.new(:sql => @sql, :temp_file => true, :temp_dir => tmp_dir).export(@name)
      with_file(@name){|d| d.should == "4,5,6\n1,2,3\n" }
    end
  end

  describe "different types of export" do
    it "gzip export" do
      File.exists?(@name).should be_false
      PgCsv.new(:sql => @sql, :type => :gzip).export(@name)
      with_gzfile(@name){|d| d.should == "4,5,6\n1,2,3\n" }
    end
    
    it "plain export" do
      PgCsv.new(:sql => @sql, :type => :plain).export(nil).should == "4,5,6\n1,2,3\n"
    end
    
    it "custom stream" do
      ex = PgCsv.new(:sql => @sql, :type => :stream)
      File.open(@name, 'w') do |stream|
        ex.export(stream)
        ex.export(stream, :sql => @sql0)
      end
      
      with_file(@name){|d| d.should == "4,5,6\n1,2,3\n1,2,3\n4,5,6\n" }
    end
    
    it "file as default" do
      PgCsv.new(:sql => @sql, :type => :file).export(@name)
      with_file(@name){|d| d.should == "4,5,6\n1,2,3\n" }            
    end
    
    it "yield export" do
      rows = []
      PgCsv.new(:sql => @sql, :type => :yield).export(nil) do |row|
        rows << row
      end
      
      rows.should == ["4,5,6\n", "1,2,3\n"]
    end
  end

  describe "integration specs" do
    it "1" do
      File.exists?(@name).should be_false
      PgCsv.new(:sql => @sql, :type => :gzip).export(@name, :delimiter => "|", :columns => %w{q w e}, :temp_file => true, :temp_dir => tmp_dir)
      with_gzfile(@name){|d| d.should == "q|w|e\n4|5|6\n1|2|3\n" }
    end
    
    it "2" do
      Zlib::GzipWriter.open(@name) do |gz|
        e = PgCsv.new(:sql => @sql, :type => :stream)
        
        e.export(gz, :delimiter => "|", :columns => %w{q w e} )
        e.export(gz, :delimiter => "*", :sql => @sql0)
      end
      
      with_gzfile(@name){|d| d.should == "q|w|e\n4|5|6\n1|2|3\n1*2*3\n4*5*6\n" }
    end
  end
  
  it "custom prepare row" do
    e = PgCsv.new(:sql => @sql)
      
    def e.prepare_row(row)
      row.split(",").join("-|-")
    end
      
    e.export(@name)
    with_file(@name){|d| d.should == "4-|-5-|-6\n1-|-2-|-3\n" }
  end
  
end