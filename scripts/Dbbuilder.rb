require_relative 'Dbman';
require 'i18n';

I18n.available_locales = [:en];

class Dbbuilder

  def initialize
    @dbh = Dbman.new.dbh;
  end

  def clean
    %w[ht_oclc_title ht_oclc_bow].each do |t|
      puts "Truncating #{t}";
      q = @dbh.prepare("TRUNCATE TABLE #{t}");
      q.execute();
    end
  end

  def load (hathifile)
    inf    = File.open(hathifile, 'r');
    outf_t = File.open('./oclc_title.tsv', 'w');
    outf_w = File.open('./oclc_word.tsv', 'w');
    # Get oclc and title from each line in hathifile
    i = 0;
    inf.each_line do |line|
      i += 1;
      puts i if i % 1000 == 0;
      cols    = line.split("\t");
      oclc_t  = cols[0];
      oclc_t.split(',').each do |oclc| # could be multiple oclcs
        title = I18n.transliterate(cols[1]);
        outf_t.puts([oclc, title].join("\t"));
          words     = title.downcase.split(' ').map{|x| x.gsub(/[^a-z]/, '')}.select{|x| x =~ /[a-z]/}.uniq;
          words.each do |w|
            outf_w.puts([oclc, w].join("\t"));
          end
      end
    end
    [inf, outf_w, outf_t].each{|f| f.close()};
    puts "loading files into tables";
    @dbh.query("LOAD DATA LOCAL INFILE '#{File.expand_path(outf_t)}' INTO TABLE ht_oclc_title (oclc, title)");
    @dbh.query("LOAD DATA LOCAL INFILE '#{File.expand_path(outf_w)}' INTO TABLE ht_oclc_bow (oclc, word)");
  end
  end

if $0 == __FILE__ then
  dbb = Dbbuilder.new();
  dbb.clean();
  dbb.load('/htapps/mwarin.babel/sporran_of_word_matching/data/hathifile_extract_cols.tsv');
end
