-- =========================================================
-- TITLE: STEAM GAMES DATASET 
-- =========================================================


-- STEP: Activating database
-- ---------------------------------------------------------
USE steam;
SET SQL_SAFE_UPDATES = 0;
SET AUTOCOMMIT = OFF;




-- =========================================================
-- SECTION: GET DATA
-- =========================================================


-- STEP: Create the table and load data from TSV file
-- ---------------------------------------------------------
CREATE TABLE games
(
 Title TEXT,
 OriginalPrice TEXT,
 DiscountedPrice TEXT,
 ReleaseDate TEXT,
 RecentReviewsSummary TEXT,
 AllReviewsSummary TEXT,
 RecentReviewsNumber TEXT,
 AllReviewsNumber TEXT,
 Developer TEXT,
 Publisher TEXT,
 PopularTags TEXT
);


-- Using TSV instead of CSV to avoid splitting fields like 'Developers,'
-- which contain multiple entries separated by commas, into separate columns.
-- ---------------------------------------------------------
LOAD DATA INFILE 'C:/myfile.txt'
INTO TABLE games
FIELDS TERMINATED BY '\t'
IGNORE 1 LINES;


-- STEP: Maintain a backup of Original table 
-- ---------------------------------------------------------
CREATE TABLE original_games AS
SELECT * FROM games;


-- STEP: Revert changes from backup when required
-- ---------------------------------------------------------
CREATE TABLE games AS
SELECT * FROM original_games;




-- =========================================================
-- SECTION: TITLE
-- =========================================================

-- STEP: Remove unwanted symbols
-- ---------------------------------------------------------
-- Excluded certain trademark symbols (e.g., ®, ™) from the title,
-- retaining only those deemed necessary.
-- ---------------------------------------------------------
UPDATE games
SET Title = REGEXP_REPLACE(Title, "[^a-zA-Z0-9:.,\\-!?'’&+=%/\\s]", "")
WHERE Title REGEXP "[^a-zA-Z0-9:.,\\-!?'’&+=%/\\s]";


-- STEP: Remove leading and trailing whitespaces
-- ---------------------------------------------------------
UPDATE games
SET Title = TRIM(Title);


-- STEP: Delete rows blank titles
-- ---------------------------------------------------------
DELETE FROM games
WHERE Title = '';


-- STEP: Delete rows with titles without alphanumeric characters
-- ---------------------------------------------------------
DELETE FROM games
WHERE Title NOT REGEXP '[A-Za-z0-9]';


-- STEP: Remove some unwanted leading characters
-- ---------------------------------------------------------
-- After the various cleaning steps, some retained special characters ended up
-- at the beginning of the title and had to be removed.
-- ---------------------------------------------------------------------
UPDATE games
SET Title  = TRIM(BOTH '-' FROM Title)
WHERE SUBSTRING(Title, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Title  = TRIM(BOTH ':' FROM Title)
WHERE SUBSTRING(Title, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Title  = TRIM(LEADING '!' FROM Title)
WHERE SUBSTRING(Title, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Title  = TRIM(LEADING '.' FROM Title)
WHERE SUBSTRING(Title, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Title  = TRIM(LEADING "'" FROM Title)
WHERE SUBSTRING(Title, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Title  = TRIM(BOTH '/' FROM Title)
WHERE SUBSTRING(Title, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Title  = TRIM(BOTH '&' FROM Title)
WHERE SUBSTRING(Title, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Title  = TRIM(Title);


-- STEP: Normalize case to Leading upercase only
-- ---------------------------------------------------------
UPDATE games
SET Title = CONCAT(
    UCASE(SUBSTRING(Title, 1, 1)),
    LCASE(SUBSTRING(Title, 2))
);


-- STEP: Delete duplicate entries
-- ---------------------------------------------------------
-- The duplicated titles were dropped as they had no information apart from the title.
-- ---------------------------------------------------------
DELETE FROM games
WHERE Title IN ('Survive or die', 'Astrominer', 'Game over', 'Our mind');


-- COMMIT;




-- =========================================================
-- SECTION: ORIGINAL & DISCOUNTED PRICE
-- =========================================================

-- STEP: Replace 'Free' with $0.0 and remove ',' and '"' from the numbers
-- ---------------------------------------------------------
UPDATE games
SET OriginalPrice = '$0.0'
WHERE OriginalPrice = 'Free';


UPDATE games
SET DiscountedPrice = '$0.0'
WHERE DiscountedPrice = 'Free';


UPDATE games
SET OriginalPrice = REPLACE(OriginalPrice, ',', '')
WHERE OriginalPrice LIKE "%,%";


UPDATE games
SET DiscountedPrice = REPLACE(DiscountedPrice, ',', '')
WHERE DiscountedPrice LIKE "%,%";


UPDATE games
SET OriginalPrice = REPLACE(OriginalPrice, '"', '')
WHERE OriginalPrice LIKE '%"%';


UPDATE games
SET DiscountedPrice = REPLACE(DiscountedPrice, '"', '')
WHERE DiscountedPrice LIKE '%"%';


-- STEP: Remove currency and round off to closest integer
-- ---------------------------------------------------------
UPDATE games
SET OriginalPrice = ROUND(CONVERT(TRIM(LEADING '$' FROM OriginalPrice), DOUBLE));


UPDATE games
SET DiscountedPrice = ROUND(CONVERT(TRIM(LEADING '$' FROM DiscountedPrice), DOUBLE));


-- STEP: Update price columns' data type from TEXT to INT
-- ---------------------------------------------------------
ALTER TABLE games
MODIFY COLUMN OriginalPrice INT;


ALTER TABLE games
MODIFY COLUMN DiscountedPrice INT;


-- COMMIT;




-- =========================================================
-- SECTION: RELEASE DATES
-- =========================================================

-- STEP: Convert date format
-- ---------------------------------------------------------
-- Using STR_TO_DATE replacing blank values and "To be announced" and "Coming soon" with NULL
-- ---------------------------------------------------------
UPDATE games
SET ReleaseDate = 
  CASE
    WHEN ReleaseDate REGEXP '^[0-9]{2}-[a-zA-Z]{3}-[0-9]{2}$' THEN STR_TO_DATE(ReleaseDate, '%d-%b-%y')
    ELSE NULL
  END;


-- STEP: Update date column
-- ---------------------------------------------------------
ALTER TABLE games
MODIFY COLUMN ReleaseDate DATE;


-- COMMIT;




-- =========================================================
-- SECTION: REVIEWS SUMMARY (RECENT & ALL-TIME)
-- =========================================================

-- STEP: Normalizing reviews
-- ---------------------------------------------------------
-- Consolidated the original four subclasses of both positive and
-- negative reviews into two categories each: 'positive' and 'negative,'
-- simplifying the classification for clarity and simplicity.
-- ---------------------------------------------------------

-- Recent reviews summary
UPDATE games
SET RecentReviewsSummary = NULL
WHERE RecentReviewsSummary = '';


UPDATE games
SET RecentReviewsSummary = "Less Reviews"
WHERE RecentReviewsSummary LIKE '%user reviews';


UPDATE games
SET RecentReviewsSummary = "Positive"
WHERE RecentReviewsSummary LIKE '%Positive';


UPDATE games
SET RecentReviewsSummary = "Negative"
WHERE RecentReviewsSummary LIKE '%Negative';


-- All reviews summary
UPDATE games
SET AllReviewsSummary = NULL
WHERE AllReviewsSummary = '';


UPDATE games
SET AllReviewsSummary = "Positive"
WHERE AllReviewsSummary LIKE '%Positive';


UPDATE games
SET AllReviewsSummary = "Negative"
WHERE AllReviewsSummary LIKE '%Negative';


-- COMMIT;




-- =========================================================
-- SECTION: REVIEWS NUMBER (RECENT & ALL-TIME)
-- =========================================================

-- STEP: Extract percentage from phrase
-- ---------------------------------------------------------
-- The entries were with regards to the positive acclaim and
-- of the form "- <percentage>% of the <number> reviews are positive".
-- Only the percentage number has been chosen to represent these fields
-- ---------------------------------------------------------

-- Recent review numbers
UPDATE games
SET RecentReviewsNumber = NULL
WHERE RecentReviewsNumber NOT LIKE "%of the%";


UPDATE games
SET RecentReviewsNumber = CONVERT(REPLACE(SUBSTRING_INDEX(SUBSTRING_INDEX(RecentReviewsNumber, ' ', 2), ' ', -1), '%', ''), UNSIGNED)
WHERE RecentReviewsNumber IS NOT NULL;


-- STEP: Update column type
-- ---------------------------------------------------------
ALTER TABLE games
MODIFY COLUMN RecentReviewsNumber INT;

-- All review numbers
UPDATE games
SET AllReviewsNumber = NULL
WHERE AllReviewsNumber NOT LIKE "%of the%";


UPDATE games
SET AllReviewsNumber = CONVERT(REPLACE(SUBSTRING_INDEX(SUBSTRING_INDEX(AllReviewsNumber, ' ', 2), ' ', -1), '%', ''), UNSIGNED)
WHERE AllReviewsNumber IS NOT NULL;


-- STEP: Update column type
-- ---------------------------------------------------------
ALTER TABLE games
MODIFY COLUMN AllReviewsNumber INT;


-- COMMIT;




-- =========================================================
-- SECTION: DEVELOPERS
-- =========================================================

-- STEP: Clean Developer names
-- ---------------------------------------------------------
UPDATE games
SET Developer = REGEXP_REPLACE(Developer, "[^a-zA-Z0-9:.,\\-!?'’&+=%/\\s]", "");


-- STEP: Change developer name separators
-- ---------------------------------------------------------
UPDATE games
SET Developer = REPLACE(Developer, ",", ";");


-- STEP: Create new column to store the very first developer name
-- ---------------------------------------------------------
-- This choice was made as there were variable number of developers
-- wherever there were multiple ones but over 70% had 1 developer name.
-- ---------------------------------------------------------
ALTER TABLE games
ADD COLUMN TopDeveloper TEXT AFTER Developer;


UPDATE games
SET TopDeveloper = TRIM(SUBSTRING_INDEX(Developer, ';', 1));


-- STEP: Normalize case
-- ---------------------------------------------------------
UPDATE games
SET TopDeveloper = CONCAT(
    UCASE(SUBSTRING(TopDeveloper, 1, 1)),
    LCASE(SUBSTRING(TopDeveloper, 2))
);


-- STEP: Drop the original developers column
-- ---------------------------------------------------------
ALTER TABLE games
DROP COLUMN Developer;


-- STEP: As for 'Titles', remove unwanted leading characters
-- ---------------------------------------------------------
UPDATE games
SET TopDeveloper = NULL
WHERE TopDeveloper NOT REGEXP '[A-Za-z0-9]';


UPDATE games
SET TopDeveloper  = TRIM(BOTH '-' FROM TopDeveloper)
WHERE SUBSTRING(TopDeveloper, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET TopDeveloper  = TRIM(BOTH '/' FROM TopDeveloper)
WHERE SUBSTRING(TopDeveloper, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET TopDeveloper  = TRIM(LEADING '.' FROM TopDeveloper)
WHERE SUBSTRING(TopDeveloper, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET TopDeveloper = TRIM(TopDeveloper);


UPDATE games
SET TopDeveloper = CONCAT(
    UCASE(SUBSTRING(TopDeveloper, 1, 1)),
    LCASE(SUBSTRING(TopDeveloper, 2))
);


-- COMMIT;




-- =========================================================
-- SECTION: PUBLISHERS
-- =========================================================

-- STEP: Remove unwanted characters and normalize case.
-- ---------------------------------------------------------
UPDATE games
SET Publisher = REGEXP_REPLACE(REGEXP_REPLACE(Publisher, '\\([^)]*\\)', ''), "[^a-zA-Z0-9:.\\-!?'’\\s]", "");


UPDATE games
SET Publisher = NULL
WHERE Publisher NOT REGEXP '[A-Za-z0-9]';


UPDATE games
SET Publisher = TRIM(Publisher);


UPDATE games
SET Publisher  = TRIM(BOTH '-' FROM Publisher)
WHERE SUBSTRING(Publisher, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Publisher  = TRIM(LEADING '.' FROM Publisher)
WHERE SUBSTRING(Publisher, 1, 1) NOT REGEXP '^[A-Za-z0-9]$';


UPDATE games
SET Publisher = TRIM(Publisher);


UPDATE games
SET Publisher = CONCAT(
    UCASE(SUBSTRING(Publisher, 1, 1)),
    LCASE(SUBSTRING(Publisher, 2))
);


-- COMMIT;




-- =========================================================
-- SECTION: GAME TAGS
-- =========================================================

-- STEP: Same approach as for 'Developers'.
-- ---------------------------------------------------------
-- Retaining only the first occurring tag in a new column.
-- Following same text cleaning procedures
-- ---------------------------------------------------------
UPDATE games
SET PopularTags = REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(PopularTags, '\\([^)]*\\)', ''), "[^a-zA-Z0-9:.,\\-\\s]", ""), ",", ";");


ALTER TABLE games
ADD COLUMN PrimaryTag TEXT;


UPDATE games
SET PrimaryTag = TRIM(SUBSTRING_INDEX(PopularTags, ';', 1));


ALTER TABLE games
DROP COLUMN PopularTags;


UPDATE games
SET PrimaryTag = NULL
WHERE PrimaryTag NOT REGEXP '[A-Za-z0-9]';


UPDATE games
SET PrimaryTag = CONCAT(
    UCASE(SUBSTRING(PrimaryTag, 1, 1)),
    LCASE(SUBSTRING(PrimaryTag, 2))
);


-- COMMIT;




-- =========================================================
-- THE END
-- =========================================================




