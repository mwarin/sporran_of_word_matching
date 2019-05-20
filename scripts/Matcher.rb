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

  def initialize (mode = {:interactive=>false, :min_score=>0.5})
    @mode = mode;
    @dbh = Dbman.new.dbh;
    @query_cache = {0 => @dbh.prepare("SELECT word FROM ht_word WHERE word_id = 0")};
    get_full_title_by_oclc_sql = 'SELECT title FROM ht_oclc_title WHERE oclc = ?';
    @get_full_title_by_oclc    = @dbh.prepare(get_full_title_by_oclc_sql);
    @stop_t = Stopword.new('title').get_hash();
    @stop_a = Stopword.new('author').get_hash();
  end

  def get_words_oclc_q (kind, search_words)
    # Caches query for variable number of WHERE-args and proportional HAVING
    wc = search_words.size;
    STDERR.puts "wc is #{wc}: #{search_words.join(',')}";
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
    search_all_words    = [search_title_words + search_author_words].uniq;
    STDERR.puts "## Search title: #{search_title}";
    STDERR.puts "## Search words: #{search_title_words.join(',')}";
    oclc_t_words = {};
    oclc_a_words = {};

    if search_all_words.empty? then
      return [];
    end

    # get a (cached) query with the right number of WHERE-args and proportional HAVING COUNT(x).
    get_title_oclcs_q  = get_words_oclc_q('title', search_title_words);
    get_author_oclcs_q = get_words_oclc_q('author', search_author_words);

    # get all ocns and their associated words based on search title
    res_t = get_title_oclcs_q.execute(*search_title_words);
    res_t.each do |row|
      oclc = row[:oclc];
      oclc_t_words[oclc] = row[:words].split(',');
    end
    res_t.free;
    res_a = get_author_oclcs_q.execute(*search_author_words);
    res_a.each do |row|
      oclc = row[:oclc];
      oclc_a_words[oclc] = row[:words].split(',');
    end
    res_a.free;

    scores     = [];
    oclc_title = {};

    # for each oclc=>[words], compare against search_title and score

    # todo: somehow repeat this for oclc_a_words
    oclc_t_words.each do |match_ocn, match_words|
      match_title = '';
      res = @get_full_title_by_oclc.execute(match_ocn);
      res.each do |row|
        match_title    = row[:title].chomp;
        match_title_words = Strutil.get_words(match_title).reject{|w| @stop_t.key?(w)};
        precision = match_words.size.to_f / search_title_words.size.to_f;
        recall    = match_words.size.to_f / (search_title_words + match_title_words).uniq.size.to_f;
        score     = (precision + recall)  / 2;
        # Only bother if score is above min_score.
        if score >= @mode[:min_score] then
          scores << {
            :oclc         => match_ocn,
            :score        => score,
            :precision    => precision,
            :recall       => recall,
            :title        => match_title,
            :search_words => search_title_words,
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
  Matcher.new({:interactive => true, :min_score=>0.67}).run();
end
