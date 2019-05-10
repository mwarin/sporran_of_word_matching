require_relative 'FileMatcher';

=begin

Reads a 2-col tsv with ID<tab>TITLE

=end

class TsvMatcher < FileMatcher
  def get_records (f)
    fh = File.open(f, 'r');
    i = 0;
    fh.each_line do |line|
      line.strip!
      id, title = line.split("\t");
      yield id, title;
    end
    fh.close();
  end
end

if $0 == __FILE__ then
  min_score = ARGV.shift;
  TsvMatcher.new(min_score.to_f, *ARGV).run();
end
