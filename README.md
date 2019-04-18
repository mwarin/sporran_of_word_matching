To get running:

0) Clone me:
git clone https://github.com/mwarin/sporran_of_word_matching.git

1) Make an .env file with the following variables set:
db_user, db_pw, db_host db_name, db_port

2) Install bundle:
bundle install --path .bundle

3) Set up db from mysql prompt:
mysql> source create.sql

4) Get latest hathifile (hathi_full_YYYYMMDD.txt.gz) from:
https://www.hathitrust.org/hathifiles

5) Extract column from hathifile:
bash scripts/extract_hathifile_cols.sh <path to unzipped hathifile>

6) Build db (several hours):
bundle exec ruby scripts/Dbbuilder.rb data/hathifile_extract_cols.tsv

7) Set stop words (optional but highly recommended).
Get a feel for the most frequent words:
bundle exec ruby scripts/Stopword.rb top 100
bundle exec ruby scripts/Stopword.rb add the of and for with (...)

8) Get matching. See Matcher.rb and FileMatcher.rb.