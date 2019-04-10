require_relative 'Dbman';
require 'i18n';

I18n.available_locales = [:en]; # this could be bad for e.g. japanese/chinese/arabic/hebrew etc. 
@dbh = Dbman.new.dbh;
get_oclcs_by_word_sql = 'SELECT oclc FROM ht_oclc_bow WHERE word = ?';
@get_oclcs_by_word    = @dbh.prepare(get_oclcs_by_word_sql);

get_full_title_by_oclc_sql = 'SELECT title FROM ht_oclc_title WHERE oclc = ?';
@get_full_title_by_oclc    = @dbh.prepare(get_full_title_by_oclc_sql);

def look_up_title (input)
  input_words = input.downcase.split(' ').map{|x| x.gsub(/[^a-z]/, '')}.select{|x| x =~ /[a-z]/}.uniq;
  oclc_words = {};

  input_words.each do |input_word|
    @get_oclcs_by_word.execute(input_word).each do |row|
      oclc = row[:oclc];
      oclc_words[oclc] ||= [];
      oclc_words[oclc] << input_word;
    end
  end
  scores     = {};
  oclc_title = {}
  oclc_words.each do |o,ws|
    ht_title = '';
    @get_full_title_by_oclc.execute(o).each do |row|
      ht_title      = row[:title].chomp;
      ht_title_wc   = ht_title.split(' ').uniq.size;
      score         = ws.size.to_f / ht_title_wc;
      scores[o]     = score;
      oclc_title[o] = ht_title; 
    end
  end
  # print sorted by score
  scores.sort_by{|k,v| v}.each do |k,v|
    puts "#{v}\t#{k}\t#{oclc_title[k]}";
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
end


if $0 == __FILE__ then
  run();
end
