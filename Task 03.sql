USE SDGAnalyticsDB
GO

--1. Data Cleaning & Normalization
--Rename fields for clarity (using SELECT AS)
-- Goal1
SELECT 
    Indicator AS Indicator_Name,
    GeoAreaName AS Country_Name,
    TimePeriod AS Year,
    Value
FROM dbo.Goal1;

-- Goal2
SELECT 
    Indicator AS Indicator_Name,
    GeoAreaName AS Country_Name,
    TimePeriod AS Year,
    Value
FROM dbo.Goal2;

-- Goal3
SELECT 
    Indicator AS Indicator_Name,
    GeoAreaName AS Country_Name,
    TimePeriod AS Year,
    Value
FROM dbo.Goal3;

-- Goal 13
SELECT 
    Indicator AS Indicator_Name,
    GeoAreaName AS Country_Name,
    TimePeriod AS Year,
    Value
FROM dbo.Goal13;


--Handle missing or inconsistent values
-- Replace NULLs in Value with 0, and trim text fields
SELECT 
    ISNULL(Value, 0) AS Cleaned_Value,
    LTRIM(RTRIM(GeoAreaName)) AS Country_Name,
    TimePeriod AS Year
FROM dbo.Goal3
WHERE Value IS NOT NULL AND GeoAreaName IS NOT NULL;

--Missing Data Cleaning for Goal1, Goal2, Goal13
-- Clean Goal1
SELECT 
    ISNULL(Value, 0) AS Cleaned_Value,
    LTRIM(RTRIM(GeoAreaName)) AS Country_Name,
    TimePeriod AS Year
FROM dbo.Goal1
WHERE Value IS NOT NULL AND GeoAreaName IS NOT NULL;

-- Clean Goal2
SELECT 
    ISNULL(Value, 0) AS Cleaned_Value,
    LTRIM(RTRIM(GeoAreaName)) AS Country_Name,
    TimePeriod AS Year
FROM dbo.Goal2
WHERE Value IS NOT NULL AND GeoAreaName IS NOT NULL;

-- Clean Goal13
SELECT 
    ISNULL(Value, 0) AS Cleaned_Value,
    LTRIM(RTRIM(GeoAreaName)) AS Country_Name,
    TimePeriod AS Year
FROM dbo.Goal13
WHERE Value IS NOT NULL AND GeoAreaName IS NOT NULL;

--2. Create Relationships with Keys
--Add surrogate primary keys and foreign keys (if needed)
-- Add primary key to Goal1
ALTER TABLE dbo.Goal1
ADD Goal1_ID INT IDENTITY(1,1) PRIMARY KEY;

-- foreign key setup (assuming you have a Countries table)
ALTER TABLE dbo.Goal1
ADD CountryCode INT;

--Missing Foreign Key Relationships
-- Create Countries table
CREATE TABLE dbo.Countries (
    CountryCode INT PRIMARY KEY,
    Country_Name NVARCHAR(100)
);

-- Add CountryCode to other tables
ALTER TABLE dbo.Goal2 ADD CountryCode INT;
ALTER TABLE dbo.Goal3 ADD CountryCode INT;
ALTER TABLE dbo.Goal13 ADD CountryCode INT;

-- Add primary keys to other tables
ALTER TABLE dbo.Goal2 ADD Goal2_ID INT IDENTITY(1,1) PRIMARY KEY;
ALTER TABLE dbo.Goal3 ADD Goal3_ID INT IDENTITY(1,1) PRIMARY KEY;
ALTER TABLE dbo.Goal13 ADD Goal13_ID INT IDENTITY(1,1) PRIMARY KEY;

-- Add foreign key constraints
ALTER TABLE dbo.Goal2 ADD CONSTRAINT Goal2_Countries FOREIGN KEY (CountryCode) REFERENCES dbo.Countries(CountryCode);
ALTER TABLE dbo.Goal3 ADD CONSTRAINT Goal3_Countries FOREIGN KEY (CountryCode) REFERENCES dbo.Countries(CountryCode);
ALTER TABLE dbo.Goal13 ADD CONSTRAINT Goal13_Countries FOREIGN KEY (CountryCode) REFERENCES dbo.Countries(CountryCode);



--3. Use of Views and CTEs
--Create a unified view across all four tables
CREATE VIEW vw_SDG_Combined AS
SELECT 'Goal1' AS Source,
       Indicator, GeoAreaName, TimePeriod, Value FROM dbo.Goal1
UNION ALL
SELECT 'Goal2' AS Source,
       Indicator, GeoAreaName, TimePeriod, Value FROM dbo.Goal2
UNION ALL
SELECT 'Goal3' AS Source,
       Indicator, GeoAreaName, TimePeriod, Value FROM dbo.Goal3
UNION ALL
SELECT 'Goal13' AS Source,
       Indicator, GeoAreaName, TimePeriod, Value FROM dbo.Goal13;
--Use CTE for ranking and aggregation
WITH RankedValues AS (
    SELECT 
        GeoAreaName,
        TimePeriod,
        Value,
        RANK() OVER (PARTITION BY GeoAreaName ORDER BY Value DESC) AS RankByValue
    FROM dbo.Goal1
)
SELECT * FROM RankedValues WHERE RankByValue = 1;



--4. Stored Procedure for Power BI
--Create a procedure to return cleaned, ranked data
CREATE PROCEDURE sp_GetCleanedSDGData
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Indicator AS Indicator_Name,
        GeoAreaName AS Country_Name,
        TimePeriod AS Year,
        ISNULL(Value, 0) AS Cleaned_Value,
        RANK() OVER (PARTITION BY GeoAreaName ORDER BY Value DESC) AS RankByValue
    FROM vw_SDG_Combined
    WHERE Value IS NOT NULL;
END;


-- 5. Verify Structure Before Power BI
--Check for NULLs, duplicates, and schema
-- Check for NULLs
SELECT COUNT(*) AS NullValues FROM dbo.Goal1 WHERE Value IS NULL;

-- Check for duplicates
SELECT Indicator, GeoAreaName, TimePeriod, COUNT(*) AS DuplicateCount
FROM dbo.Goal1
GROUP BY Indicator, GeoAreaName, TimePeriod
HAVING COUNT(*) > 1;

-- Populate Countries table with distinct country names
INSERT INTO dbo.Countries (CountryCode, Country_Name)
SELECT DISTINCT ROW_NUMBER() OVER (ORDER BY GeoAreaName), GeoAreaName
FROM (
    SELECT GeoAreaName FROM dbo.Goal1
    UNION
    SELECT GeoAreaName FROM dbo.Goal2
    UNION
    SELECT GeoAreaName FROM dbo.Goal3
    UNION
    SELECT GeoAreaName FROM dbo.Goal13
) AS AllCountries;

-- Update CountryCode in each table
UPDATE G
SET G.CountryCode = C.CountryCode
FROM dbo.Goal1 G
JOIN dbo.Countries C ON LTRIM(RTRIM(G.GeoAreaName)) = C.Country_Name;

-- Repeat for Goal2, Goal3, Goal13
UPDATE G SET G.CountryCode = C.CountryCode
FROM dbo.Goal2 G JOIN dbo.Countries C ON LTRIM(RTRIM(G.GeoAreaName)) = C.Country_Name;

UPDATE G SET G.CountryCode = C.CountryCode
FROM dbo.Goal3 G JOIN dbo.Countries C ON LTRIM(RTRIM(G.GeoAreaName)) = C.Country_Name;

UPDATE G SET G.CountryCode = C.CountryCode
FROM dbo.Goal13 G JOIN dbo.Countries C ON LTRIM(RTRIM(G.GeoAreaName)) = C.Country_Name;

--Verify structure for all tables
-- Check for NULLs
SELECT COUNT(*) AS NullValues_Goal2 FROM dbo.Goal2 WHERE Value IS NULL;
SELECT COUNT(*) AS NullValues_Goal3 FROM dbo.Goal3 WHERE Value IS NULL;
SELECT COUNT(*) AS NullValues_Goal13 FROM dbo.Goal13 WHERE Value IS NULL;

-- Check for duplicates
SELECT Indicator, GeoAreaName, TimePeriod, COUNT(*) AS DuplicateCount
FROM dbo.Goal2 GROUP BY Indicator, GeoAreaName, TimePeriod HAVING COUNT(*) > 1;

SELECT Indicator, GeoAreaName, TimePeriod, COUNT(*) AS DuplicateCount
FROM dbo.Goal3 GROUP BY Indicator, GeoAreaName, TimePeriod HAVING COUNT(*) > 1;

SELECT Indicator, GeoAreaName, TimePeriod, COUNT(*) AS DuplicateCount
FROM dbo.Goal13 GROUP BY Indicator, GeoAreaName, TimePeriod HAVING COUNT(*) > 1;

-- Verify schema
EXEC sp_help 'dbo.Goal1';
EXEC sp_help 'dbo.Goal2';
EXEC sp_help 'dbo.Goal3';
EXEC sp_help 'dbo.Goal13';

