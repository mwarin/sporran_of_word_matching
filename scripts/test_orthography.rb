=begin

Counts number of "words" (str.split(/\s+/)) that aren't in the Common, 
Latin or Inherited unicode scripts. Takes a file path as input.

Useful for checking your assumptions about treating all text as /[a-zA-Z]/.

=end

@unicode_langs = %w<
Arabic Armenian Balinese Bengali Bopomofo
Braille Buginese Buhid Canadian_Aboriginal Carian
Cham Cherokee Coptic Cuneiform Cypriot
Cyrillic Deseret Devanagari Ethiopic Georgian
Glagolitic Gothic Greek Gujarati Gurmukhi
Han Hangul Hanunoo Hebrew Hiragana
Kannada Katakana Kayah_Li Kharoshthi Khmer
Lao Lepcha Limbu Linear_B Lycian
Lydian Malayalam Mongolian Myanmar New_Tai_Lue
Nko Ogham Ol_Chiki Old_Italic Old_Persian
Oriya Osmanya Phags_Pa Phoenician Rejang
Runic Saurashtra Shavian Sinhala Sundanese
Syloti_Nagri Syriac Tagalog Tagbanwa Tai_Le
Tamil Telugu Thaana Thai Tibetan
Tifinagh Ugaritic Vai Yi>;
# skipping:
# Common, Latin, Inherited

@unicode_langs_rx = {};
@unicode_langs.each do |lang|
  @unicode_langs_rx[lang] = Regexp.new(/(\p{#{lang}}+)/);
end

def run
  tot_lang_count = {};
  @unicode_langs.each do |lang|
    tot_lang_count[lang] = 0;
  end

  fh = File.new(ARGV.shift, 'r');
  fh.each_line do |line|
    lang_count = {};
    line.strip!
    ws = line.split(/\s+/);
    wc = ws.size;

    @unicode_langs_rx.each do |lang, rx|
      count = check_lang_count(line, rx);
      lang_count[lang] = count if count > 0;
      tot_lang_count[lang] += count;
    end
    if !lang_count.empty?
      puts line;
      puts "Of #{wc}: #{lang_count}";
    end
  end  
  fh.close();
  puts "------------\n";
  puts ":: TOTALS ::";
  puts "------------\n";
  tot_lang_count.sort_by{|k,v| v}.each do |lang, count|
    puts "#{lang}:#{count}" if count > 0;
  end
end

def check_lang_count (str, lang)
  (str =~ lang).nil? ? 0 : str.scan(lang).size;
end

run();
