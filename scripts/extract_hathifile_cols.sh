hathifile=$1;
# cols 8, 12, 26 are oclc, title, author.
cut -f8,12,26 $hathifile | sort -u > data/hathifile_extract_cols.tsv;
