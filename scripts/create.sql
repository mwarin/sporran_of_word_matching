DROP TABLE IF EXISTS ht_oclc_title;
DROP TABLE IF EXISTS ht_oclc_bow;
CREATE TABLE ht_oclc_title(oclc INTEGER PRIMARY KEY, title VARCHAR(250));
CREATE TABLE ht_oclc_bow(oclc INTEGER, word VARCHAR(50), stop TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (oclc, word));

CREATE INDEX ht_oclc_bow_word USING BTREE ON ht_oclc_bow (oclc);
CREATE INDEX ht_oclc_title_title USING BTREE ON ht_oclc_title (title); 
