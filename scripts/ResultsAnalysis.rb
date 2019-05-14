require 'json';

=begin

Takes a single results file as input, does some counts, and produces a brief report.

=end

class ResultsAnalysis

  def initialize (file)
    @file = file;
    @number_of = {
      :record            => 0,
      :parse_error       => 0,
      :x_recommended     => Hash.new(0),
      :total_recommended => 0,
      :x_score           => Hash.new(0),
      :x_precision       => Hash.new(0),
      :x_recall          => Hash.new(0),
      :distinct_ocn      => {}
    };
  end

  def run
    fh = File.open(@file, 'r');
    fh.each_line do |line|
      analyze_line(line);
    end
    fh.close();
    @number_of.each do |label, value|
      if label =~ /^distinct_/ then
        puts "#{label}\t#{value.size}";
      else
        if value.class == Hash then
          puts label;
          value.keys.sort.each do |k|
            puts "\t#{k}\t#{value[k]}";
        end
        else
          puts "#{label}\t#{value}";
        end
      end
    end
  end

  def analyze_line (line)
    count(:record);
    begin
      res = JSON.parse(line);
      count(:x_recommended, res["results"].size);
      res["results"].each do |r|
        count(:total_recommended);
        count_distinct(:distinct_ocn, r["oclc"]);
        count(:x_score, sprintf("%.3s", r["score"]));
        count(:x_precision, sprintf("%.3s", r["precision"]));
        count(:x_recall, sprintf("%.3s", r["recall"]));
      end
    rescue JSON::ParserError => e
      count(:parse_error);
    end
  end

  def count (key1, key2 = nil)
    key2.nil? ?
      @number_of[key1] += 1
    :
      @number_of[key1][key2] += 1
  end

  def count_distinct (key1, key2)
    @number_of[key1][key2] = 1;
  end

end

if $0 == __FILE__ then
  f  = ARGV.shift;
  ra = ResultsAnalysis.new(f);
  ra.run();
end
