require_relative 'Dbman';
require_relative 'Strutil';

class Dbbuilder
  attr_reader :word_cache, :cache_hit, :cache_miss;
  def initialize
    @dbh = Dbman.new.dbh;
    @word_cache      = {};
    @word_cache_max  = 20000;
    @get_word_id_sth = @dbh.prepare("SELECT word_id FROM ht_word WHERE word = ?");
    @set_word_id_sth = @dbh.prepare("INSERT INTO ht_word (word) VALUES (?)");
    @get_last_id_sth = @dbh.prepare("SELECT LAST_INSERT_ID() AS id");
    @cache_hit  = 0;
    @cache_miss = 0;
    @cache_full = 0;
  end

  def truncate_tables
    %w[ht_oclc_title ht_oclc_author ht_oclc_bow ht_word].each do |t|
      puts "Truncating #{t}";
      q = @dbh.prepare("TRUNCATE TABLE #{t}");
      q.execute();
    end
  end

  def get_word_id (word)
    # memoized
    if @word_cache.key?(word) then
      @cache_hit += 1;
      @word_cache[word][:freq] += 1;
      return @word_cache[word][:val];
    end
    @cache_miss += 1;

    word_id = nil;
    res = @get_word_id_sth.execute(word);
    res.each do |row|
      word_id = row[:word_id];
    end
    res.free;

    if word_id.nil? then
      @set_word_id_sth.execute(word);
      word_id = @set_word_id_sth.last_id;
    end
    if word_id.nil? then
      raise "unable to find word_id for #{word}";
    end
    @word_cache[word] = {:val => word_id, :freq => 1};

    # When cache is full, throw out the least frequent 1/5th.
    if @word_cache.keys.size > @word_cache_max then
      @cache_full += 1;
      @word_cache.sort_by{|k,v| v[:freq]}.first(@word_cache_max / 5).each do |k,v|
        @word_cache.delete(k);
      end
    end

    return word_id;
  end
  
  def process_line (line)
    cols    = line.strip.split("\t");
    oclc_t  = cols[0];
    title   = cols[1];
    author  = cols[2];

    words = Strutil.get_words(title) + Strutil.get_words(author);
    return if words.empty?
    oclc_t.split(',').each do |oclc| # could be multiple oclcs
      next if oclc.to_i == 0;
      @outf_t.puts([oclc, title].join("\t"))  if !title.nil?  && !title.empty?;
      @outf_a.puts([oclc, author].join("\t")) if !author.nil? && !author.empty?;
      words.each do |w|
        @outf_w.puts([oclc, get_word_id(w)].join("\t"));
      end
    end
  end

  def load (hathifile)
    inf     = File.open(hathifile, 'r');
    @outf_t = File.open('./oclc_title.tsv', 'w');
    @outf_a = File.open('./oclc_author.tsv', 'w');
    @outf_w = File.open('./oclc_word.tsv', 'w');
    # Get oclc and title from each line in hathifile
    i = 0;
    inf.each_line do |line|
      i += 1;
      if i % 10000 == 0 then
        puts "#{i} #{Time.new} cache size #{@word_cache.keys.size}, cache full #{@cache_full} times, cache hit/miss #{@cache_hit}/#{@cache_miss}";
      end
      process_line(line);
    end
    puts i;
    [inf, @outf_t, @outf_a, @outf_w].each{|f| f.close()};
    puts "loading files into tables";
    @dbh.query("LOAD DATA LOCAL INFILE '#{File.expand_path(@outf_t)}' IGNORE INTO TABLE ht_oclc_title CHARACTER SET utf8mb4 (oclc, title)");
    @dbh.query("LOAD DATA LOCAL INFILE '#{File.expand_path(@outf_a)}' IGNORE INTO TABLE ht_oclc_author CHARACTER SET utf8mb4 (oclc, author)");
    @dbh.query("LOAD DATA LOCAL INFILE '#{File.expand_path(@outf_w)}' IGNORE INTO TABLE ht_oclc_bow (oclc, word_id)");

    puts "cleaning up...";
    @dbh.query("DELETE FROM ht_oclc_title  WHERE title  = '' OR oclc = 0");
    @dbh.query("DELETE FROM ht_oclc_author WHERE author = '' OR oclc = 0");
  end
end

if $0 == __FILE__ then
  if ARGV[0].nil? then
    raise "Pass path to hathi-oclc-title.tsv file as 1st arg";
  else
    puts Time.new;
    dbb = Dbbuilder.new();
    dbb.truncate_tables();
    dbb.load(ARGV[0]);
    puts Time.new;
    puts "cache hit/miss = #{dbb.cache_hit} / #{dbb.cache_miss}";
  end
end
