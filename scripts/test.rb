# coding: utf-8
require_relative 'Dbman';
require_relative 'Strutil';
require_relative 'TsvMatcherOptionalAuthor';

dbh = Dbman.new.dbh;
sth = dbh.prepare("SELECT 3+3 AS maths");
sth.execute.each do |row|
  puts row[:maths];
end

puts Strutil.get_words("1789-1795. La Révolution à Dijon.").join(',');

## Test with/without author col

TsvMatcherOptionalAuthor.new({:min_score=>0.66, :author=>true, :debug=>true}, "data/hathi_with_author_col.tsv").run();
puts "\n\n";
TsvMatcherOptionalAuthor.new({:min_score=>0.66, :author=>false, :debug=>true}, "data/hathi_without_author_col.tsv").run();
