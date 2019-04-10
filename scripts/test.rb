require_relative 'Dbman';

dbh = Dbman.new.dbh;
sth = dbh.prepare("SELECT 3+3 AS maths");
sth.execute.each do |row|
  puts row[:maths];
end
