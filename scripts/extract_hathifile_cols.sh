hathifile='/htapps/mwarin.babel/phdb_scripts/data/builds/current/hathi_full.txt';
head -100000 $hathifile | cut -f8,12 | sort -u > data/hathifile_extract_cols.tsv;
