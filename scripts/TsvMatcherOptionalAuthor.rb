require_relative 'FileMatcher';

=begin

Reads a 2-col tsv with ID<tab>TITLE

=end

class TsvMatcherOptionalAuthor < FileMatcher
  def get_records (f)
    fh = File.open(f, 'r');
    i = 0;
    fh.each_line do |line|
      line.strip!
      cols   = line.split("\t");
      id     = cols[0];
      title  = cols[1];
      author = cols[2] || '';

      yield id, title, author;
    end
    fh.close();
  end
end

if $0 == __FILE__ then
  mode = {
    :min_score => ARGV.shift.to_i,
    :author    => true
  }
  TsvMatcherOptionalAuthor.new(mode, *ARGV).run();
end
