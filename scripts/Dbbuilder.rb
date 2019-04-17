require_relative 'Dbman';
require 'i18n';

I18n.available_locales = [:en];

@@latin_common_rx  = Regexp.new(/\p{Latin}|\p{Common}/);
@@common_non_num_rx = Regexp.new(/[\p{Common}&&[^0-9]]/);
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

  def clean
    %w[ht_oclc_title ht_oclc_bow ht_word].each do |t|
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

  def check_pct_common_latin (str)
    str.scan(@@latin_common_rx).size.to_f / str.length;
  end

  def process_line (line)
    cols    = line.strip.split("\t");
    oclc_t  = cols[0];
    title_t = cols[1];
    title   = '';
    return if title_t.nil?
    if (check_pct_common_latin(title_t) >= 0.75) then
      # make sure we don't destroy non-latin text
      title = I18n.transliterate(title_t);
    else
      title = title_t;        
    end
    words = title.downcase.split(@@common_non_num_rx).uniq;
    puts "title [#{title}]";
    puts "words [#{words.join(',')}]"
    oclc_t.split(',').each do |oclc| # could be multiple oclcs
      @outf_t.puts([oclc, title].join("\t"));
      words.each do |w|
        @outf_w.puts([oclc, get_word_id(w)].join("\t"));
      end
    end
  end
  
  def load (hathifile)
    inf    = File.open(hathifile, 'r');
    @outf_t = File.open('./oclc_title.tsv', 'w');
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
    [inf, @outf_w, @outf_t].each{|f| f.close()};
    puts "loading files into tables";
    @dbh.query("LOAD DATA LOCAL INFILE '#{File.expand_path(@outf_t)}' IGNORE INTO TABLE ht_oclc_title (oclc, title)");
    @dbh.query("LOAD DATA LOCAL INFILE '#{File.expand_path(@outf_w)}' IGNORE INTO TABLE ht_oclc_bow (oclc, word_id)");
  end
end

if $0 == __FILE__ then
  if ARGV[0].nil? then
    raise "Pass path to hathi-oclc-title.tsv file as 1st arg";
  else
    puts Time.new;
    dbb = Dbbuilder.new();
    dbb.clean();
    dbb.load(ARGV[0]);
    puts Time.new;
    puts "cache hit/miss = #{dbb.cache_hit} / #{dbb.cache_miss}";
  end
end
