require_relative 'Dbman';
require 'i18n';

I18n.available_locales = [:en];
dbh = Dbman.new.dbh;

%w[ht_oclc_title ht_oclc_bow].each do |t|
  puts "Truncating #{t}";
  q = dbh.prepare("TRUNCATE TABLE #{t}");
  q.execute();
end

insert_title = dbh.prepare('INSERT INTO ht_oclc_title (oclc, title) VALUES(?, ?)');
insert_words = dbh.prepare ('INSERT INTO ht_oclc_bow (oclc, word) VALUES(?, ?)');

hathifile = '/htapps/mwarin.babel/sporran_of_word_matching/data/hathifile_extract_cols.tsv';
inf       = File.open(hathifile, 'r');

# Get oclc and title from each line in hathifile
inf.each_line do |line|
  cols    = line.split("\t");
  oclc_t  = cols[0];
  
  oclc_t.split(',').each do |oclc| # could be multiple oclcs
    
    title = I18n.transliterate(cols[1]);
    puts title;
    insert_title.execute(oclc, title);
    
    # Get words, downcased, de-diacriticed and unique.
    words     = title.downcase.split(' ').map{|x| x.gsub(/[^a-z]/, '')}.select{|x| x =~ /[a-z]/}.uniq;
    words.each do |w|
      insert_words.execute(oclc, w);
    end
  end
end

get_freq_sql = 'SELECT word, COUNT(word) AS c FROM ht_oclc_bow GROUP BY word HAVING c > 1 ORDER BY c';
get_freq = dbh.prepare(get_freq_sql);
get_freq.execute() do |row|
  puts "#{row[0]}\t#{row[1]}";
end
