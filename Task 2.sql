USE [Task 2]
Go

--Exploratory Data Analysis (EDA)
--Check for Missing Values
SELECT 
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN ADDRESS1 IS NULL THEN 1 ELSE 0 END) AS Missing_ADDRESS1,
    SUM(CASE WHEN POSTCODE IS NULL THEN 1 ELSE 0 END) AS Missing_POSTCODE,
    SUM(CASE WHEN CURRENT_ENERGY_EFFICIENCY IS NULL THEN 1 ELSE 0 END) AS Missing_CURRENT_ENERGY
FROM dbo.certificates;

--Detect Outliers (e.g., unusually high CO2 emissions)
SELECT 
    LMK_KEY, CO2_EMISSIONS_CURRENT
FROM dbo.certificates
WHERE CO2_EMISSIONS_CURRENT > (
    SELECT AVG(CO2_EMISSIONS_CURRENT) + 2 * STDEV(CO2_EMISSIONS_CURRENT) FROM dbo.certificates
);



-- 2. Data Cleaning with CTEs and Views
--CTE to Normalize Postcodes and Remove Duplicates
WITH CleanedCertificates AS (
    SELECT *,
        TRIM(UPPER(POSTCODE)) AS NormalizedPostcode,
        ROW_NUMBER() OVER (PARTITION BY LMK_KEY ORDER BY LODGEMENT_DATE DESC) AS rn
    FROM dbo.certificates
)
SELECT * 
INTO dbo.Certificates_Cleaned
FROM CleanedCertificates
WHERE rn = 1;


--Create a View for Cleaned Data
CREATE VIEW vw_Certificates_Cleaned AS
SELECT 
    LMK_KEY, NormalizedPostcode, CURRENT_ENERGY_EFFICIENCY, CO2_EMISSIONS_POTENTIAL, PROPERTY_TYPE
FROM dbo.Certificates_Cleaned;



--3. Stored Procedure for Automated Cleaning
CREATE PROCEDURE sp_CleanCertificates
AS
BEGIN
    -- Remove rows with NULL critical fields
    DELETE FROM dbo.certificates
    WHERE CURRENT_ENERGY_RATING IS NULL OR POSTCODE IS NULL;

    -- Update inconsistent casing
    UPDATE dbo.certificates
    SET POSTCODE = UPPER(TRIM(POSTCODE))
    WHERE POSTCODE IS NOT NULL;
END;


--To run it:
EXEC sp_CleanCertificates;



-- 4. Use of System Functions and Aggregates
--Ranking Properties by Energy Efficiency
SELECT 
    LMK_KEY, CURRENT_ENERGY_EFFICIENCY,
    RANK() OVER (ORDER BY CURRENT_ENERGY_EFFICIENCY DESC) AS EnergyRank
FROM dbo.certificates;


 --Aggregate Summary by Property Type
SELECT 
    PROPERTY_TYPE,
    COUNT(*) AS Total,
    AVG(CURRENT_ENERGY_EFFICIENCY) AS AvgEnergy,
    AVG(CO2_EMISSIONS_POTENTIAL) AS AvgCO2
FROM dbo.certificates
GROUP BY PROPERTY_TYPE;


--Using ISNUMERIC() to Identify Non-Numeric Entries
SELECT 
    LMK_KEY, CO2_EMISSIONS_CURRENT
FROM dbo.certificates
WHERE ISNUMERIC(CO2_EMISSIONS_CURRENT) = 0;

--Using TRY_CAST() to Safely Convert and Filter Valid Numbers
SELECT 
    LMK_KEY,
    TRY_CAST(CO2_EMISSIONS_CURRENT AS FLOAT) AS CO2_Validated,
    TRY_CAST(CURRENT_ENERGY_EFFICIENCY AS FLOAT) AS Energy_Validated,
    TRY_CAST(ENERGY_CONSUMPTION_CURRENT AS FLOAT) AS Consumption_Validated
FROM dbo.certificates
WHERE TRY_CAST(CO2_EMISSIONS_CURRENT AS FLOAT) IS NOT NULL
  AND TRY_CAST(CURRENT_ENERGY_EFFICIENCY AS FLOAT) IS NOT NULL
  AND TRY_CAST(ENERGY_CONSUMPTION_CURRENT AS FLOAT) IS NOT NULL;
