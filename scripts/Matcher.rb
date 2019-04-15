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
    get_oclcs_by_word_sql = 'SELECT b.oclc FROM ht_oclc_bow AS b JOIN ht_word AS w ON (b.word_id = w.word_id) WHERE w.stop = 0 AND w.word = ?';
    @get_oclcs_by_word    = @dbh.prepare(get_oclcs_by_word_sql);
    
    get_full_title_by_oclc_sql = 'SELECT title FROM ht_oclc_title WHERE oclc = ?';
    @get_full_title_by_oclc    = @dbh.prepare(get_full_title_by_oclc_sql);
    
    @stop = Stopword.new.get_list();
  end
  
  def look_up_title (search_title)
    search_title_words = search_title
                  .downcase
                  .split(' ')
                  .map{|x| x.gsub(/[^a-z]/, '')}
                  .select{|x| x =~ /[a-z]/}
                  .reject{|x| @stop.include?(x)}
                  .uniq;
    oclc_words = {};

    # put some memoization here, so that the most common words are cached
    # when looking up multiple titles
    search_title_words.each do |search_title_word|
      @get_oclcs_by_word.execute(search_title_word).each do |row|
        oclc = row[:oclc];
        oclc_words[oclc] ||= [];
        oclc_words[oclc] << search_title_word;
      end
    end
    search_title_wc = search_title_words.size;
    scores     = [];
    oclc_title = {}
    oclc_words.each do |match_ocn, match_words|
      match_title = '';
      @get_full_title_by_oclc.execute(match_ocn).each do |row|
        match_title    = row[:title].chomp;
        match_title_words = match_title.downcase.split(' ').uniq.reject{|x| @stop.include?(x)};
        
        precision = match_words.size.to_f / search_title_words.size.to_f;
        recall    = match_words.size.to_f / (search_title_words + match_title_words).uniq.size.to_f;
        score     = (precision + recall)  / 2;
        
        scores << {
          :oclc=>match_ocn,
          :score=>score,
          :title=>match_title,
          :search_words=>search_title_words,
          :match_words=>match_words,
          :precision=>precision,
          :recall=>recall
        };
      end
    end
    if @mode[:interactive] then
      # print sorted by score
      scores.sort_by{|h| h[:score]}.each do |h|
        puts "#{h[:score]}\tp#{h[:precision]}\tr#{h[:recall]}\t#{h[:oclc]}\t#{h[:search_words].join(',')}\t#{h[:match_words].join(',')}";
      end
      puts "Total matching: #{scores.size}";
    end
    return scores;
  end
  
  def run
    if ARGV.empty? then
      while search_title = gets.chomp do
        break if search_title == '';
        look_up_title(search_title);
      end
    else
      ARGV.each do |search_title|
        look_up_title(search_title);
      end
    end
  end
end
  
if $0 == __FILE__ then
  Matcher.new({:interactive => true}).run();
end
