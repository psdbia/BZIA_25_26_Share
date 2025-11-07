USE Northwind2025;
GO

-- Add rpt schema if doesn't exist
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'rpt'
)
BEGIN
    EXEC('CREATE SCHEMA rpt');
END


-- Drop tables if they exist
IF OBJECT_ID('rpt.Calendar', 'U') IS NOT NULL DROP TABLE rpt.Calendar;
IF OBJECT_ID('rpt.CanadianHolidays', 'U') IS NOT NULL DROP TABLE rpt.CanadianHolidays;
GO

-- Create Calendar table
CREATE TABLE rpt.Calendar (
    DayID INT,
    DateValue DATE PRIMARY KEY,
    CalYear INT,
    CalQuarter INT,
    CalMonth INT,
    CalMonthName VARCHAR(10),
    CalMonthShort VARCHAR(3),
    CalWeek INT,
    CalDay INT,
    CalDayName VARCHAR(10),
    CalDayShort VARCHAR(3),
    IsWeekday BIT,
    FiscalYear INT,
    FiscalQuarter INT,
    FiscalMonth INT,
    FiscMonthName VARCHAR(10),
    FiscMonthShort VARCHAR(3),
    IsHoliday BIT,
    HolidayName VARCHAR(100),
    HolidayType VARCHAR(50)
);
GO

-- Create Canadian Holidays table
CREATE TABLE rpt.CanadianHolidays (
    HolidayDate DATE PRIMARY KEY,
    HolidayName VARCHAR(100),
    HolidayType VARCHAR(50)
);
GO

-- Generate dynamic Canadian holidays for years 2022–2051
DECLARE @Year INT = 2022;

WHILE @Year <= 2051
BEGIN
    -- Fixed-date statutory holidays
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    VALUES
        (DATEFROMPARTS(@Year, 1, 1), 'New Year''s Day', 'Statutory'),
        (DATEFROMPARTS(@Year, 7, 1), 'Canada Day', 'Statutory'),
        (DATEFROMPARTS(@Year, 12, 25), 'Christmas Day', 'Statutory'),
        (DATEFROMPARTS(@Year, 12, 26), 'Boxing Day', 'Statutory'),
        (DATEFROMPARTS(@Year, 11, 11), 'Remembrance Day', 'Observance');

    -- Labour Day: First Monday in September
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    SELECT DATEADD(DAY, (8 - DATEPART(WEEKDAY, DATEFROMPARTS(@Year, 9, 1))) % 7, DATEFROMPARTS(@Year, 9, 1)),
           'Labour Day', 'Statutory';

    -- Thanksgiving: Second Monday in October
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    SELECT DATEADD(DAY, ((8 - DATEPART(WEEKDAY, DATEFROMPARTS(@Year, 10, 1))) % 7) + 7, DATEFROMPARTS(@Year, 10, 1)),
           'Thanksgiving', 'Statutory';

    -- Civic Holiday (Natal Day in Nova Scotia): First Monday in August
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    SELECT DATEADD(DAY, (8 - DATEPART(WEEKDAY, DATEFROMPARTS(@Year, 8, 1))) % 7, DATEFROMPARTS(@Year, 8, 1)),
           'Natal Day', 'Civic';

    -- Victoria Day: Monday before May 25
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    SELECT DATEADD(DAY, -((DATEPART(WEEKDAY, DATEFROMPARTS(@Year, 5, 25)) + 6) % 7), DATEFROMPARTS(@Year, 5, 25)),
           'Victoria Day', 'Civic';

    -- Nova Scotia Heritage Day: Third Monday in February
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    SELECT DATEADD(DAY, ((8 - DATEPART(WEEKDAY, DATEFROMPARTS(@Year, 2, 1))) % 7) + 14, DATEFROMPARTS(@Year, 2, 1)),
           'Nova Scotia Heritage Day', 'Statutory';

    -- Easter Sunday calculation (Meeus/Jones/Butcher algorithm)
    DECLARE @a INT = @Year % 19;
    DECLARE @b INT = @Year / 100;
    DECLARE @c INT = @Year % 100;
    DECLARE @d INT = @b / 4;
    DECLARE @e INT = @b % 4;
    DECLARE @f INT = (@b + 8) / 25;
    DECLARE @g INT = (@b - @f + 1) / 3;
    DECLARE @h INT = (19 * @a + @b - @d - @g + 15) % 30;
    DECLARE @i INT = @c / 4;
    DECLARE @k INT = @c % 4;
    DECLARE @l INT = (32 + 2 * @e + 2 * @i - @h - @k) % 7;
    DECLARE @m INT = (@a + 11 * @h + 22 * @l) / 451;
    DECLARE @month INT = (@h + @l - 7 * @m + 114) / 31;
    DECLARE @day INT = ((@h + @l - 7 * @m + 114) % 31) + 1;
    DECLARE @Easter DATE = DATEFROMPARTS(@Year, @month, @day);

    -- Easter Sunday
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    VALUES (@Easter, 'Easter Sunday', 'Religious');

    -- Good Friday (2 days before Easter)
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    VALUES (DATEADD(DAY, -2, @Easter), 'Good Friday', 'Religious');

    -- Easter Monday (1 day after Easter)
    INSERT INTO rpt.CanadianHolidays (HolidayDate, HolidayName, HolidayType)
    VALUES (DATEADD(DAY, 1, @Easter), 'Easter Monday', 'Religious');

    SET @Year = @Year + 1;
END
GO

-- Declare date range
DECLARE @StartDate DATE = '2022-01-01';
DECLARE @EndDate DATE = DATEADD(DAY, -1, DATEADD(YEAR, 30, @StartDate));
DECLARE @TotalDays INT = DATEDIFF(DAY, @StartDate, @EndDate) + 1;

-- Generate and insert calendar data
;WITH L1 AS (
    SELECT 0 AS n FROM master.dbo.spt_values
),
L2 AS (
    SELECT TOP (@TotalDays)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM L1 AS A CROSS JOIN L1 AS B
),
Dates AS (
    SELECT DATEADD(DAY, n, @StartDate) AS DateValue
    FROM L2
)
INSERT INTO rpt.Calendar
SELECT
    CAST(FORMAT(d.DateValue, 'yyyyMMdd') AS INT) AS DayID,
    d.DateValue,
    YEAR(d.DateValue) AS CalYear,
    DATEPART(QUARTER, d.DateValue) AS CalQuarter,
    MONTH(d.DateValue) AS CalMonth,
    DATENAME(MONTH, d.DateValue) AS CalMonthName,
    LEFT(DATENAME(MONTH, d.DateValue), 3) AS CalMonthShort,
    DATEPART(WEEK, d.DateValue) AS CalWeek,
    DAY(d.DateValue) AS CalDay,
    DATENAME(WEEKDAY, d.DateValue) AS CalDayName,
    LEFT(DATENAME(WEEKDAY, d.DateValue), 3) AS CalDayShort,

--***** Fiscal Calcs Start Below *****--
    CASE WHEN DATEPART(WEEKDAY, d.DateValue) IN (1, 7) THEN 0 ELSE 1 END AS IsWeekday,
    CASE 
        WHEN MONTH(d.DateValue) >= 4 THEN YEAR(d.DateValue) + 1
        ELSE YEAR(d.DateValue)  
    END AS FiscalYear,
    CASE 
        WHEN MONTH(d.DateValue) BETWEEN 4 AND 6 THEN 1
        WHEN MONTH(d.DateValue) BETWEEN 7 AND 9 THEN 2
        WHEN MONTH(d.DateValue) BETWEEN 10 AND 12 THEN 3
        ELSE 4
    END AS FiscalQuarter,
    CASE 
        WHEN MONTH(d.DateValue) >= 4 THEN MONTH(d.DateValue) - 3
        ELSE MONTH(d.DateValue) + 9
    END AS FiscalMonth,
    

DATENAME(MONTH, DATEFROMPARTS(YEAR(d.DateValue), 
    CASE 
        WHEN MONTH(d.DateValue) >= 4 THEN MONTH(d.DateValue) - 3
        ELSE MONTH(d.DateValue) + 9
    END, 1)) AS FiscMonthName,



LEFT(DATENAME(MONTH, DATEFROMPARTS(YEAR(d.DateValue), 
    CASE 
        WHEN MONTH(d.DateValue) >= 4 THEN MONTH(d.DateValue) - 3
        ELSE MONTH(d.DateValue) + 9
    END, 1)), 3) AS FiscMonthShort,
    
    CASE WHEN h.HolidayDate IS NOT NULL THEN 1 ELSE 0 END AS IsHoliday,
    h.HolidayName,
    h.HolidayType
FROM Dates d
LEFT JOIN rpt.CanadianHolidays h ON d.DateValue = h.HolidayDate;
GO

/***** Comment this out if you wish to retain the table *****/
IF OBJECT_ID('rpt.CanadianHolidays', 'U') IS NOT NULL DROP TABLE rpt.CanadianHolidays;
GO

