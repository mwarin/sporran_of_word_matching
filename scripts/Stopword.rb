require_relative 'Dbman';

=begin

Set mass stopwordyness based on frequency or add/remove stop words.

Set words with freq greater than 1%:
$ bundle exec ruby scripts/update_stopwords.rb set 0.01

Add specific words to stop list:
$ bundle exec ruby scripts/update_stopwords.rb add apple orange banana

Remove specific words from stop list:
$ bundle exec ruby scripts/update_stopwords.rb del pear coconut kiwi

=end

class Stopword

  def initialize
    @dbh = Dbman.new.dbh
    @udpate_single_sth = @dbh.prepare("UPDATE ht_oclc_bow SET stop = ? WHERE word = ?");
  end
  
  def run
    
    case ARGV[0]
    when 'set'# Set threshold for what becomes a stopword.
      threshold = 0.01;
      if ARGV[1] =~ /^0\.[0-9]+$/ then
        threshold = ARGV[1].to_f;
      end
      puts "overriding threshold, now #{threshold}";
      set_threshold(threshold);
    when 'add' # add word(s) to stop list
      ARGV.shift;
      ARGV.each do |arg|
        add(arg);
      end
    when 'del' # remove words from stop list
      ARGV.shift;
      ARGV.each do |arg|
        del(arg);
      end
    when 'top' # show the x (=10) most frequent words and whether or not they are in the stop list
      count = 10;
      if ARGV[1] =~ /^\d+$/ then
        count = ARGV[1].to_i;
      end
      top(count);
    else
      raise "ummm what is #{ARGV[0]}?";
    end
  end
  
  def set_threshold (threshold)
    # Reset all stopwords.
    puts "resetting...";
    reset_all_sql = "UPDATE ht_oclc_bow SET stop = 0 WHERE stop = 1";
    reset_all_q   = @dbh.prepare(reset_all_sql);
    reset_all_q.execute();
    
    # Get total word count
    get_word_total_sql = 'SELECT COUNT(*) AS c FROM ht_oclc_bow';
    get_word_total_q   = @dbh.prepare(get_word_total_sql);
    tot = 0;
    get_word_total_q.execute().each do |row|
      tot = row[:c];
    end
    puts "total words #{tot}";
    
    # Declare all words with a freq% higher than threshold to be stopwords
    get_word_freq_sql = "SELECT word, COUNT(word) AS c FROM ht_oclc_bow GROUP BY word HAVING c > 1 ORDER BY c DESC";
    get_word_freq_q   = @dbh.prepare(get_word_freq_sql);
    set_stop_word_sql = "UPDATE ht_oclc_bow SET stop = 1 WHERE word = ?";
    set_stop_word_q   = @dbh.prepare(set_stop_word_sql);
    get_word_freq_q.execute().each do |row|
      w = row[:word];
      c = row[:c];
      f = c.to_f / tot;
      if f >= threshold then
        puts "STOP: #{w} (count #{c}, freq #{f})";
        set_stop_word_q.execute(w);
      end
    end
  end
  
  def add (word)
    puts "adding #{word} to stop list";
    @udpate_single_sth.execute(1, word);
  end
  
  def del (word)
    puts "removing #{word} from stop list";
    @udpate_single_sth.execute(0, word);
  end
  
  def get_list
    sth = @dbh.prepare("SELECT DISTINCT word FROM ht_oclc_bow WHERE stop = 1 ORDER BY word");
    stop_list = [];
    sth.execute().each do |row|
      stop_list << row[:word];
    end
    
    return stop_list;
  end

  def top (count)
    sql = %w[
      SELECT word, stop, COUNT(word) AS c 
      FROM ht_oclc_bow
      GROUP BY word, stop
      HAVING c > 1000
      ORDER BY c DESC
      LIMIT 0, ?
    ].join(' ');
    sth = @dbh.prepare(sql);
    sth.execute(count).each do |row|
      puts [:c, :word, :stop].map{ |x| row[x] }.join("\t");
    end
  end
end

if $0 == __FILE__ then
  Stopword.new.run();
end
