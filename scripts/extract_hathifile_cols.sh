hathifile='/htapps-dev/mwarin.babel/phdb_scripts/data/builds/current/hathi_full.txt';
head -100 $hathifile | cut -f8,12 | sort -u > data/hathifile_extract_cols.tsv;
