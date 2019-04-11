hathifile=$1;
cut -f8,12 $hathifile | sort -u > data/hathifile_extract_cols.tsv;
