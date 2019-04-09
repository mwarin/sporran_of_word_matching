require 'sqlite3';
require 'i18n';

I18n.available_locales = [:en]; # this could be bad for e.g. japanese/chinese/arabic/hebrew etc. 
@db = SQLite3::Database.open('sporran.db');
get_oclcs_by_word_sql = 'SELECT oclc FROM ht_oclc_bow WHERE word = ?';
@get_oclcs_by_word    = @db.prepare(get_oclcs_by_word_sql);

get_full_title_by_oclc_sql = 'SELECT title FROM ht_oclc_title WHERE oclc = ?';
@get_full_title_by_oclc    = @db.prepare(get_full_title_by_oclc_sql);

def look_up_title (input)
  input_words = input.downcase.split(' ').map{|x| x.gsub(/[^a-z]/, '')}.select{|x| x =~ /[a-z]/}.uniq;
  oclc_words = {};

  input_words.each do |input_word|
    @get_oclcs_by_word.bind_params(input_word);
    @get_oclcs_by_word.execute! do |row|
      oclc = row[0];
      oclc_words[oclc] ||= [];
      oclc_words[oclc] << input_word;
    end
    @get_oclcs_by_word.reset!
  end
  scores = {};
  oclc_words.each do |o,ws|
    ht_title = '';
    @get_full_title_by_oclc.bind_params(o);
    @get_full_title_by_oclc.execute! do |row|
      ht_title = row[0].chomp;
      ht_title_wc = ht_title.split(' ').size;
      score = ws.size.to_f / ht_title_wc;
      scores[o] = score;
      puts "#{o}\t#{ht_title}\t#{ws.join(',')}\t#{score}";
    end
    @get_full_title_by_oclc.reset!
  end
end

def run
  if ARGV.empty? then
    while input = gets.chomp do
      break if input == '';
      look_up_title(input)
    end
  else
    ARGV.each do |input|
      look_up_title(input);
    end
  end
  close_all();
end

def close_all
  [@get_oclcs_by_word, @get_full_title_by_oclc, @db].each do |x|
    x.close();
  end
end

if $0 == __FILE__ then
  run();
end
