require_relative 'Dbman';
require_relative 'Stopword';
require 'i18n';
I18n.available_locales = [:en]; # this could be bad for e.g. japanese/chinese/arabic/hebrew etc. 

=begin

Run interactively from command line:
$ bundle exec ruby scripts/Matcher.rb "history of lobsters"

... or use as an object:

require 'Matcher';
matcher = Matcher.new();
results = matcher.look_up_title("history of lobsters");

=end

class Matcher

  def initialize (mode = {:interactive => false})
    @mode = mode;
    @dbh = Dbman.new.dbh;
    get_oclcs_by_word_sql = 'SELECT oclc FROM ht_oclc_bow WHERE word = ?';
    @get_oclcs_by_word    = @dbh.prepare(get_oclcs_by_word_sql);
    
    get_full_title_by_oclc_sql = 'SELECT title FROM ht_oclc_title WHERE oclc = ?';
    @get_full_title_by_oclc    = @dbh.prepare(get_full_title_by_oclc_sql);
    
    @stop = Stopword.new.get_list();
  end
  
  def look_up_title (input)
    input_words = input
                  .downcase
                  .split(' ')
                  .map{|x| x.gsub(/[^a-z]/, '')}
                  .select{|x| x =~ /[a-z]/}
                  .reject{|x| @stop.include?(x)}
                  .uniq;
    oclc_words = {};

    # put some memoization here, so that the most common words are cached
    # when looking up multiple titles
    input_words.each do |input_word|
      @get_oclcs_by_word.execute(input_word).each do |row|
        oclc = row[:oclc];
        oclc_words[oclc] ||= [];
        oclc_words[oclc] << input_word;
      end
    end
    scores     = [];
    oclc_title = {}
    oclc_words.each do |o,ws|
      ht_title = '';
      @get_full_title_by_oclc.execute(o).each do |row|
        ht_title    = row[:title].chomp;
        ht_title_wc = ht_title.split(' ').uniq.reject{|x| @stop.include?(x)}.size;
        # write scoring algorithm so it penalizes missing words from the search term.
        # currently this unfairly favors one word titles with one matching word
        score       = ws.size.to_f / ht_title_wc;
        scores << {:oclc => o, :score => score, :title => ht_title};
      end
    end
    if @mode[:interactive] then
      # print sorted by score
      scores.sort_by{|h| h[:score]}.each do |h|
        puts "#{h[:score]}\t#{h[:oclc]}\t#{h[:title]}";
      end
      puts "Total matching: #{scores.size}";
    end
    return scores;
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
end
  
if $0 == __FILE__ then
  Matcher.new({:interactive => true}).run();
end
