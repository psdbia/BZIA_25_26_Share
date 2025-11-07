/***** Set DB Name *****/
USE Northwind2025;  

GO

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Calendar')
BEGIN
    /***** Set Schema and Table Name *****/
    DROP TABLE rpt.Calendar    
END

GO

-- Create the Calendar table
/***** Set Schema and Table Name *****/
CREATE TABLE rpt.Calendar
(
    DayID INT,
    DateValue DATETIME PRIMARY KEY,
    Year INT,
    Quarter INT,
    Month INT,
    MonthName VARCHAR(10),
	MonthShort VARCHAR(3),
    Week INT,
    Day INT,
	DayName VARCHAR(10),
	DayShort VARCHAR(3),
    IsWeekday BIT
)

GO

-- Declare variables
/***** Start Date *****/
DECLARE @StartDate DATE = '2022-01-01'
/***** Start Year Duration *****/
DECLARE @EndDate DATE = DATEADD(year, 5, GETDATE())
DECLARE @Date DATE = @StartDate
DECLARE @DayID INT = CAST(FORMAT(CAST(@StartDate AS DATE), 'yyyyMMdd') AS INT)


-- Populate the Calendar table
WHILE @Date <= @EndDate
BEGIN
    /***** Set Schema and Table Name *****/
    INSERT INTO rpt.Calendar (DayID, DateValue, Year, Quarter, Month,  MonthName, MonthShort, Week, Day, DayName, DayShort, IsWeekday)
    VALUES (
        @DayID,
        @Date,
        YEAR(@Date),
        DATEPART(QUARTER, @Date),
        MONTH(@Date),
        DATENAME(MONTH, @Date),
		LEFT(DATENAME(MONTH, @Date),3),
        DATEPART(WEEK, @Date),
        DAY(@Date),
		DATENAME(WEEKDAY, @Date),
		LEFT(DATENAME(WEEKDAY, @Date),3),
        CASE WHEN DATEPART(WEEKDAY, @Date) IN (1, 7) THEN 0 ELSE 1 END -- Set IsWeekday to 0 for Saturday (1) and Sunday (7), and 1 for weekdays
    )

    -- Increment the date and day ID
    SET @Date = DATEADD(DAY, 1, @Date)
    SET @DayID = @DayID + 1
END


