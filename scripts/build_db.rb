require 'sqlite3';
require 'i18n';

I18n.available_locales = [:en];
db = SQLite3::Database.open('sporran.db');
commands = [
  'DROP TABLE IF EXISTS ht_oclc_title',
  'DROP TABLE IF EXISTS ht_oclc_bow',
  'CREATE TABLE ht_oclc_title(oclc INTEGER PRIMARY KEY, title VARCHAR(250))',
  'CREATE TABLE ht_oclc_bow(oclc INTEGER, word VARCHAR(50), PRIMARY KEY (oclc, word))'
];

commands.each do |command|
  puts command;
  db.execute(command);
end

insert_title = db.prepare 'INSERT INTO ht_oclc_title (oclc, title) VALUES(?, ?)';
insert_words = db.prepare 'INSERT INTO ht_oclc_bow (oclc, word) VALUES(?, ?)';

hathifile = '/htapps-dev/mwarin.babel/sporran_of_word_matching/data/hathifile_extract_cols.tsv';
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
get_freq = db.prepare(get_freq_sql);
get_freq.execute! do |row|
  puts "#{row[0]}\t#{row[1]}";
end

# close all the things, order matters
[inf, insert_title, insert_words, get_freq].each do |x|
  x.close();
end
