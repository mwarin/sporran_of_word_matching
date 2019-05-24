require_relative 'Dbman';
require_relative 'Stopword';
require_relative 'Strutil';

=begin

Run from command line:
$ bundle exec ruby scripts/Matcher.rb "history of lobsters"

... or interactively:

$ bundle exec ruby scripts/Matcher.rb
> history of lobsters

... or use as an object:

require 'Matcher';
matcher = Matcher.new();
results = matcher.look_up_title("history of lobsters");

=end

class Matcher

  @@factory_settings = {
    :interactive => false,
    :debug       => false,
    :title       => true,
    :author      => false,
    :min_score   => 0.5
  };

  def initialize (mode = {})
    @mode = @@factory_settings.merge(mode);
    STDERR.puts "## mode: #{@mode}";
    @dbh  = Dbman.new.dbh;
    @query_cache = {0 => @dbh.prepare("SELECT word FROM ht_word WHERE word_id = 0")};
    get_full_title_by_oclc_sql = 'SELECT t.title, a.author FROM ht_oclc_title AS t LEFT JOIN ht_oclc_author AS a ON (t.oclc = a.oclc) WHERE t.oclc = ?';
    @get_full_title_by_oclc    = @dbh.prepare(get_full_title_by_oclc_sql);
    @stop_t = Stopword.new('title').get_hash();
    @stop_a = Stopword.new('author').get_hash();
  end

  # Caches query for variable number of WHERE-args and proportional HAVING
  def get_words_oclc_q (kind, search_words)
    wc = search_words.size;
    # STDERR.puts "wc #{wc} #{kind}";
    if !@query_cache.key?(wc) then
      qmarks = (['?'] * wc).join(',');
      # if there are e.g. 8 search_words then require at least 8/2 in the HAVING.
      sql = %W[
        SELECT b.oclc, COUNT(b.word_id) AS c, GROUP_CONCAT(w.word) AS words
        FROM ht_oclc_bow AS b
        JOIN ht_word     AS w ON (b.word_id = w.word_id)
        WHERE w.kind = '#{kind}' AND w.stop = 0 AND w.word IN (#{qmarks})
        GROUP BY b.oclc HAVING c > #{wc / 2}
      ].join(' ');
      # puts "caching query (@query_cache[#{wc}]): #{sql}";
      q = @dbh.prepare(sql);
      @query_cache[wc] = q;
    end

    return @query_cache[wc];
  end

  def look_up_title (search_title, search_author='')
    search_title_words  = Strutil.get_words(search_title).reject{|w| @stop_t.key?(w)};
    search_author_words = Strutil.get_words(search_author).reject{|w| @stop_a.key?(w)};
    search_all_words    = (search_title_words + search_author_words).uniq;

    if @mode[:debug] then
      STDERR.puts "## Search title: #{search_title}";
      STDERR.puts "## Search author: #{search_author}" if @mode[:author];
      STDERR.puts "## Search words: #{search_all_words.join(',')}";
    end
    
    oclc_words = {};
    if search_all_words.empty? then
      return [];
    end

    # get a (cached) query with the right number of WHERE-args and proportional HAVING COUNT(x).
    get_title_oclcs_q  = get_words_oclc_q('title', search_title_words);
    get_author_oclcs_q = get_words_oclc_q('author', search_author_words);

    # Get all the oclcs associated with all the words in search author/title
    [get_title_oclcs_q.execute(*search_title_words),      
     get_author_oclcs_q.execute(*search_author_words)].each do |res|
      res.each do |row|
        oclc = row[:oclc];
        oclc_words[oclc] ||= [];
        oclc_words[oclc] << row[:words].split(',');
      end
      res.free;
    end

    scores     = [];
    oclc_title = {};

    # for each oclc=>[words], compare against search_title/author and score
    oclc_words.each do |match_ocn, match_words|
      match_words = match_words.flatten.sort.uniq;
      res = @get_full_title_by_oclc.execute(match_ocn);
      res.each do |row|

        true_pos  = match_words & search_all_words;
        false_pos = match_words - search_all_words;
        false_neg = search_all_words - match_words;

        precision = true_pos.size.to_f / (true_pos.size + false_pos.size);
        recall    = true_pos.size.to_f / (true_pos.size + false_neg.size);
        score     = (precision + recall) / 2;

        if @mode[:debug] then
          puts "true_pos  = #{match_words & search_all_words}";
          puts "false_pos = #{match_words - search_all_words}";
          puts "false_neg = #{search_all_words - match_words}";
          puts "p #{precision} = #{true_pos.size.to_f} / #{(true_pos.size + false_pos.size)}";
          puts "r #{recall}    = #{true_pos.size.to_f} / #{(true_pos.size + false_neg.size)}";
          puts "s #{score}     = #{(precision + recall)} / 2";
        end

        if precision > 1.0 || recall > 1.0 then
          raise RangeError.new("Bad math!");
        end

        # Only bother if score is above min_score.
        if score >= @mode[:min_score] then
          scores << {
            :oclc         => match_ocn,
            :score        => score,
            :precision    => precision,
            :recall       => recall,
            :title        => row[:title],
            :author       => row[:author],
            :search_words => search_all_words,
            :match_words  => match_words,
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
  Matcher.new({:interactive=>true, :debug=>true, :min_score=>0.67}).run();
end
