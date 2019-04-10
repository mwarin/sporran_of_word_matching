DROP TABLE IF EXISTS ht_oclc_title;
DROP TABLE IF EXISTS ht_oclc_bow;
CREATE TABLE ht_oclc_title(oclc INTEGER PRIMARY KEY, title VARCHAR(250));
CREATE TABLE ht_oclc_bow(oclc INTEGER, word VARCHAR(50), PRIMARY KEY (oclc, word));
