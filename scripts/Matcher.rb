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

  def initialize (mode = {:interactive=>false, :min_score=>0.5})
    @mode = mode;
    @dbh = Dbman.new.dbh;
    @query_cache = {};
    get_full_title_by_oclc_sql = 'SELECT title FROM ht_oclc_title WHERE oclc = ?';
    @get_full_title_by_oclc    = @dbh.prepare(get_full_title_by_oclc_sql);
    @stop = Stopword.new.get_list();
  end

  def get_words_oclc_q (search_words)
    # Caches query for variable number of WHERE-args and proportional HAVING
    if !@query_cache.key?(search_words.size) then
      qmarks = (['?'] * search_words.size).join(',');
      # if there are e.g. 8 search_words then require at least 8/2 in the HAVING.
      sql    = %W[
        SELECT b.oclc, COUNT(b.word_id) AS c, GROUP_CONCAT(w.word) AS words
        FROM ht_oclc_bow AS b
        JOIN ht_word     AS w ON (b.word_id = w.word_id)
        WHERE w.stop = 0 AND w.word IN (#{qmarks})
        GROUP BY b.oclc HAVING c > #{search_words.size / 2}
      ].join(' ');
      # puts "caching query (@query_cache[#{search_words.size}]): #{sql}";
      q = @dbh.prepare(sql);
      @query_cache[search_words.size] = q;
    end

    return @query_cache[search_words.size];
  end

  def str_to_clean_arr (str)
    str
      .downcase
      .split(' ')
      .map{|x| x.gsub(/[^a-z]/, '')}
      .select{|x| x =~ /[a-z]/}
      .reject{|x| @stop.include?(x)}
      .uniq;
  end
  
  def look_up_title (search_title)
    search_title_words = str_to_clean_arr(search_title);
    puts "## Search title: #{search_title}";
    puts "## Search words: #{search_title_words.join(',')}";
    oclc_words = {};

    # get a (cached) query with the right number of WHERE-args and proportional HAVING COUNT(x).
    get_oclcs_q = get_words_oclc_q(search_title_words);
    
    # get all ocns and their associated words based on search title
    res = get_oclcs_q.execute(*search_title_words);
    res.each do |row|
      oclc = row[:oclc];
      oclc_words[oclc] = row[:words].split(',')
    end
    res.free;

    scores     = [];
    oclc_title = {}

    # for each oclc=>[words], compare against search_title and score
    oclc_words.each do |match_ocn, match_words|
      match_title = '';
      res = @get_full_title_by_oclc.execute(match_ocn);
      res.each do |row|
        match_title    = row[:title].chomp;
        match_title_words = str_to_clean_arr(match_title);
        precision = match_words.size.to_f / search_title_words.size.to_f;
        recall    = match_words.size.to_f / (search_title_words + match_title_words).uniq.size.to_f;
        score     = (precision + recall)  / 2;
        # Only bother if score is above min_score.
        if score >= @mode[:min_score] then
          scores << {
            :oclc         => match_ocn,
            :score        => score,
            :title        => match_title,
            :search_words => search_title_words,
            :match_words  => match_words,
            :precision    => precision,
            :recall       => recall
          };
        end
      end
      res.free;
    end
    if @mode[:interactive] then
      # print sorted by score
      puts %w[score prec recall oclc match_w title].join("\t");
      scores.sort_by{|h| h[:score]}.each do |h|
        puts ['%.3f' % h[:score],
              '%.3f' % h[:precision],
              '%.3f' % h[:recall],
              h[:oclc],
              h[:match_words].join(','),
              h[:title],
             ].join("\t");
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
  Matcher.new({:interactive => true, :min_score=>0.33}).run();
end
