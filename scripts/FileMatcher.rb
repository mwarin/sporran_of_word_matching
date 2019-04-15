require_relative 'Matcher';

class FileMatcher
  def initialize (min_score, *files)
    @min_score = min_score;
    @files     = files;
    @matcher = Matcher.new({:interactive=>false, :min_score=>@min_score});
  end

  def run
    @files.each do |f|
      fh = File.open(f, 'r');
      fh.each_line do |line|
        line.strip!
        puts "# #{line}";
        scores = @matcher.look_up_title(line);
        if scores.empty? then
          puts "N/A";
        else
          scores.sort_by{|x| x[:score]}.each do |s|
            puts "#{s[:score]}\t#{s[:oclc]}\t#{s[:title]}";
          end
        end
      end
      fh.close();
    end
  end  
end

if $0 == __FILE__ then
  min_score = ARGV.shift;
  FileMatcher.new(min_score.to_f, *ARGV).run();
end
