require_relative 'Matcher';

=begin

Adds file reading capability to Matcher.

From commandline:

$ bundle exec ruby scripts/FileMatcher.rb <limit 0.0-1.0> <list of files>

From code:

fm = FileMatcher.new(limit, *list_of_files);
fm.run();

=end

class FileMatcher
  def initialize (min_score, *files)
    @min_score = min_score;
    @files     = files;
    @matcher   = Matcher.new({:interactive=>false, :min_score=>@min_score});
  end

  def run
    @files.each do |f|
      fh = File.open(f, 'r');
      fh.each_line do |line|
        line.strip!
        results = @matcher.look_up_title(line);
        if results.empty? then
          puts "N/A";
        else
          results.sort_by{|x| x[:score]}.each do |r|
            puts [:score, :oclc, :title].map{|x| r[x]}.join("\t");
          end
        end
        puts "---";
      end
      fh.close();
    end
  end  
end

if $0 == __FILE__ then
  min_score = ARGV.shift;
  FileMatcher.new(min_score.to_f, *ARGV).run();
end
