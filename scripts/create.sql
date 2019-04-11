DROP TABLE IF EXISTS ht_oclc_title;
DROP TABLE IF EXISTS ht_oclc_bow;
CREATE TABLE ht_oclc_title(oclc INTEGER PRIMARY KEY, title VARCHAR(250)) ENGINE = MyISAM;
CREATE TABLE ht_oclc_bow(oclc INTEGER, word VARCHAR(50), stop TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (oclc, word)) ENGINE = MyISAM;

-- DROP INDEX ht_oclc_bow_word ON ht_oclc_bow;
-- DROP INDEX ht_oclc_title_title ON ht_oclc_title;

CREATE INDEX ht_oclc_bow_word    USING HASH ON ht_oclc_bow (word);
CREATE INDEX ht_oclc_title_title USING HASH ON ht_oclc_title (title); 
