DROP TABLE IF EXISTS ht_oclc_title;
DROP TABLE IF EXISTS ht_word;
DROP TABLE IF EXISTS ht_oclc_bow;

CREATE TABLE ht_oclc_title(oclc INTEGER, title VARCHAR(250));
CREATE TABLE ht_word(word_id INTEGER NOT NULL AUTO_INCREMENT, word VARCHAR(50) NOT NULL, stop TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (word_id));
CREATE TABLE ht_oclc_bow(oclc INTEGER, word_id INTEGER, PRIMARY KEY (oclc, word_id));

ALTER TABLE ht_word       MODIFY word  VARCHAR(50)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE ht_oclc_title MODIFY title VARCHAR(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- DROP INDEX ht_oclc_bow_word ON ht_oclc_bow;
-- DROP INDEX ht_oclc_title_title ON ht_oclc_title;

CREATE INDEX ht_word_word        USING BTREE ON ht_word (word);
CREATE INDEX ht_word_stop        USING BTREE ON ht_word (stop);
CREATE INDEX ht_oclc_bow_word_id USING BTREE ON ht_oclc_bow (word_id);
CREATE INDEX ht_oclc_title_title USING BTREE ON ht_oclc_title (title);
CREATE INDEX ht_oclc_title_oclc  USING BTREE ON ht_oclc_title (oclc); 
