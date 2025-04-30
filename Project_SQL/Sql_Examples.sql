-- This comprehensive MS SQL script demonstrates advanced SQL concepts

-- It includes temporary table creation, data population, and examples of:
-- - Window Functions (all types)
-- - Various JOIN types
-- - PIVOT and UNPIVOT
-- - String Aggregation (STUFF + FOR XML PATH)
-- - Pattern Matching (LIKE)
-- - Modulo operator
-- - Advanced Date Functions (ISO Week, YTD, MTD, WTD)
-- - Recursive CTEs
-- - JSON Handling
-- - Dynamic SQL
-- - Other useful functions (ISNULL, COALESCE, CAST, CONVERT, IIF, CHOOSE)

-- Clean up temporary tables if they exist from a previous run
IF OBJECT_ID('tempdb..#Customers') IS NOT NULL
    DROP TABLE #Customers;
IF OBJECT_ID('tempdb..#Orders') IS NOT NULL
    DROP TABLE #Orders;
IF OBJECT_ID('tempdb..#Products') IS NOT NULL -- Adding a products table for JOIN examples
    DROP TABLE #Products;
IF OBJECT_ID('tempdb..#SalesData') IS NOT NULL -- Temporary table for PIVOT/UNPIVOT
    DROP TABLE #SalesData;




-- 1. Create Local Temporary Table for Customers
CREATE TABLE #Customers (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100),
    City VARCHAR(50),
    Email VARCHAR(100),
    RegistrationDate DATE
);




-- 2. Populate #Customers with Synthetic Data
--    Inserting 100 synthetic customer records.
DECLARE @i INT = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO #Customers (CustomerID, CustomerName, City, Email, RegistrationDate)
    VALUES (
        @i,
        'Customer ' + CAST(@i AS VARCHAR(10)),
        CASE @i % 5
            WHEN 0 THEN 'New York'
            WHEN 1 THEN 'London'
            WHEN 2 THEN 'Paris'
            WHEN 3 THEN 'Berlin'
            ELSE 'Tokyo'
        END,
        'customer' + CAST(@i AS VARCHAR(10)) +
        CASE @i % 3
            WHEN 0 THEN '@example.com'
            WHEN 1 THEN '@test.org'
            ELSE '@web.net'
        END,
        DATEADD(day, -CAST(RAND() * 1000 AS INT), GETDATE()) -- Random registration date within last ~2.7 years
    );
    SET @i = @i + 1;
END;




-- 3. Create Local Temporary Table for Products
CREATE TABLE #Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(50),
    Price DECIMAL(10, 2)
);




-- 4. Populate #Products with Synthetic Data
--    Inserting 20 synthetic product records.
DECLARE @k INT = 1;
WHILE @k <= 20
BEGIN
    INSERT INTO #Products (ProductID, ProductName, Category, Price)
    VALUES (
        @k,
        'Product ' + CAST(@k AS VARCHAR(10)),
        CASE @k % 3
            WHEN 0 THEN 'Electronics'
            WHEN 1 THEN 'Books'
            ELSE 'Clothing'
        END,
        CAST(RAND() * 100 + 5 AS DECIMAL(10, 2)) -- Price between 5 and 105
    );
    SET @k = @k + 1;
END;




-- 5. Create Local Temporary Table for Orders
CREATE TABLE #Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    ProductID INT, -- Added ProductID
    OrderDate DATE,
    Quantity INT,  -- Added Quantity
    TotalAmount DECIMAL(10, 2)
);




-- 6. Populate #Orders with Synthetic Data
--    Inserting 1000 synthetic order records.
DECLARE @j INT = 1;
DECLARE @CustomerID INT;
DECLARE @ProductID INT;
DECLARE @OrderDate DATE;
DECLARE @Quantity INT;
DECLARE @ProductPrice DECIMAL(10, 2);
DECLARE @TotalAmount DECIMAL(10, 2);

WHILE @j <= 1000
BEGIN
    -- Randomly select a CustomerID
    SET @CustomerID = (SELECT TOP 1 CustomerID FROM #Customers ORDER BY NEWID());

    -- Randomly select a ProductID and get its price
    SELECT TOP 1 @ProductID = ProductID, @ProductPrice = Price FROM #Products ORDER BY NEWID();

    -- Generate a random date within the last 2 years
    SET @OrderDate = DATEADD(day, -CAST(RAND() * 730 AS INT), GETDATE());

    -- Generate a random quantity between 1 and 5
    SET @Quantity = CAST(RAND() * 4 + 1 AS INT);

    -- Calculate TotalAmount
    SET @TotalAmount = @Quantity * @ProductPrice;

    INSERT INTO #Orders (OrderID, CustomerID, ProductID, OrderDate, Quantity, TotalAmount)
    VALUES (@j, @CustomerID, @ProductID, @OrderDate, @Quantity, @TotalAmount);

    SET @j = @j + 1;
END;



-- --- WINDOW FUNCTIONS (OVER PARTITION BY) EXAMPLES ---


-- Example 1: Aggregate Window Functions (SUM, AVG, COUNT, MIN, MAX)
--            Calculate total, average, count, min, and max order amount per customer.
SELECT
    'Exmpl1 - Aggregate Windows' AS ExampleInfo, -- Combined Example Number and Description
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    o.TotalAmount,
    SUM(o.TotalAmount) OVER (PARTITION BY o.CustomerID) AS CustomerTotalAmount,
    AVG(o.TotalAmount) OVER (PARTITION BY o.CustomerID) AS CustomerAverageAmount,
    COUNT(o.OrderID) OVER (PARTITION BY o.CustomerID) AS CustomerOrderCount,
    MIN(o.TotalAmount) OVER (PARTITION BY o.CustomerID) AS CustomerMinOrderAmount,
    MAX(o.TotalAmount) OVER (PARTITION BY o.CustomerID) AS CustomerMaxOrderAmount
FROM #Orders o
ORDER BY o.CustomerID, o.OrderDate
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- Example 2: Ranking Window Functions (ROW_NUMBER, RANK, DENSE_RANK, NTILE)
--            Rank orders within each customer partition by order date and amount.
SELECT
    'Exmpl2 - Ranking Windows' AS ExampleInfo, -- Combined Example Number and Description
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    o.TotalAmount,
    ROW_NUMBER() OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate ASC, o.TotalAmount DESC) AS OrderRowNumber, -- Unique sequential rank
    RANK() OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate ASC, o.TotalAmount DESC) AS OrderRank,         -- Rank with gaps for ties
    DENSE_RANK() OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate ASC, o.TotalAmount DESC) AS OrderDenseRank, -- Rank with no gaps for ties
    NTILE(4) OVER (PARTITION BY o.CustomerID ORDER BY o.TotalAmount DESC) AS SpendingQuartile -- Divide customers' orders into 4 spending groups (quartiles)
FROM #Orders o
ORDER BY o.CustomerID, o.OrderDate
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY;




-- Example 3: Value Window Functions (LAG, LEAD)
--            Get previous and next order details for each customer.
SELECT
    'Exmpl3 - Value Windows' AS ExampleInfo, -- Combined Example Number and Description
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    o.TotalAmount,
    LAG(o.OrderDate, 1, NULL) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS PreviousOrderDate,
    LAG(o.TotalAmount, 1, 0) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS PreviousOrderAmount,
    LEAD(o.OrderDate, 1, NULL) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS NextOrderDate,
    LEAD(o.TotalAmount, 1, 0) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS NextOrderAmount
FROM #Orders o
ORDER BY o.CustomerID, o.OrderDate
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- Example 4: Frame Clause (ROWS BETWEEN)
--            Calculate a 3-order moving average of total amount for each customer.
SELECT
    'Exmpl4 - Frame Clause' AS ExampleInfo, -- Combined Example Number and Description
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    o.TotalAmount,
    AVG(o.TotalAmount) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg3Orders -- Average of current and previous 2 orders
FROM #Orders o
ORDER BY o.CustomerID, o.OrderDate
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;





-- --- JOIN EXAMPLES ---


-- Example 6: INNER JOIN
--            Select orders with corresponding customer and product details.
SELECT
    'Exmpl6 - INNER JOIN' AS ExampleInfo, -- Combined Example Number and Description
    o.OrderID,
    c.CustomerName,
    p.ProductName,
    o.OrderDate,
    o.TotalAmount
FROM #Orders o
INNER JOIN #Customers c ON o.CustomerID = c.CustomerID -- Only include rows where CustomerID matches in both tables
INNER JOIN #Products p ON o.ProductID = p.ProductID     -- Only include rows where ProductID matches in both tables
ORDER BY o.OrderID
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- Example 7: LEFT JOIN (or LEFT OUTER JOIN)
--            Select all customers and their orders (if any).
SELECT
    'Exmpl7 - LEFT JOIN' AS ExampleInfo, -- Combined Example Number and Description
    c.CustomerID,
    c.CustomerName,
    o.OrderID,
    o.OrderDate,
    o.TotalAmount
FROM #Customers c
LEFT JOIN #Orders o ON c.CustomerID = o.CustomerID -- Include all customers, even if they have no orders
ORDER BY c.CustomerID, o.OrderDate
OFFSET 0 ROWS FETCH NEXT 15 ROWS ONLY; -- Show some customers with and without orders




-- Example 8: RIGHT JOIN (or RIGHT OUTER JOIN)
--            Select all orders and their corresponding customer details (if any).
--            Less common than LEFT JOIN, can often be rewritten as LEFT JOIN.
SELECT
    'Exmpl8 - RIGHT JOIN' AS ExampleInfo, -- Combined Example Number and Description
    o.OrderID,
    c.CustomerName,
    o.OrderDate,
    o.TotalAmount
FROM #Customers c
RIGHT JOIN #Orders o ON c.CustomerID = o.CustomerID -- Include all orders, even if the CustomerID doesn't exist in #Customers
ORDER BY o.OrderID
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- Example 9: FULL OUTER JOIN
--            Select all customers and all orders, matching where possible.
--            Includes customers with no orders and orders with no matching customer (if any exist).
SELECT
    'Exmpl9 - FULL OUTER JOIN' AS ExampleInfo, -- Combined Example Number and Description
    c.CustomerID AS Customer_ID,
    c.CustomerName,
    o.OrderID AS Order_ID,
    o.OrderDate,
    o.TotalAmount
FROM #Customers c
FULL OUTER JOIN #Orders o ON c.CustomerID = o.CustomerID -- Include all rows from both tables
ORDER BY c.CustomerID, o.OrderID
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY; -- Show a mix




-- Example 10: CROSS JOIN
--             Combines every row from the first table with every row from the second table.
--             Use with caution, can produce very large result sets.
SELECT
    'Exmpl10 - CROSS JOIN' AS ExampleInfo, -- Combined Example Number and Description
    c.CustomerName,
    p.ProductName
FROM #Customers c
CROSS JOIN #Products p
ORDER BY c.CustomerName, p.ProductName
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY; -- Limit output significantly!




-- --- PIVOT AND UNPIVOT EXAMPLES ---

-- Create a temporary table for PIVOT/UNPIVOT demonstration
IF OBJECT_ID('tempdb..#SalesData') IS NOT NULL
    DROP TABLE #SalesData;

CREATE TABLE #SalesData (
    SaleYear INT,
    SaleQuarter VARCHAR(2),
    Amount DECIMAL(10, 2)
);

INSERT INTO #SalesData (SaleYear, SaleQuarter, Amount)
VALUES
(2023, 'Q1', 1500.00),
(2023, 'Q2', 2200.00),
(2023, 'Q3', 1800.00),
(2023, 'Q4', 2500.00),
(2024, 'Q1', 1700.00),
(2024, 'Q2', 2300.00);




-- Example 11: Simple PIVOT
--             Rotate rows into columns. Show total sales amount per year, broken down by quarter.
SELECT
    'Exmpl11 - Simple PIVOT' AS ExampleInfo, -- Combined Example Number and Description
    SaleYear, [Q1], [Q2], [Q3], [Q4]
FROM
    (SELECT SaleYear, SaleQuarter, Amount FROM #SalesData) AS SourceData
PIVOT
    (
        SUM(Amount)             -- The aggregate function applied to the value column
        FOR SaleQuarter IN ([Q1], [Q2], [Q3], [Q4]) -- The column whose values become column headers
    ) AS PivotTable;




-- Example 12: Dynamic PIVOT
--             PIVOTing when the column values are not known beforehand.
--             Requires dynamic SQL. Show total sales amount per quarter, broken down by year.
DECLARE @PivotColumns NVARCHAR(MAX), @SQLQuery NVARCHAR(MAX);

-- Get the list of unique years for the PIVOT columns
SELECT @PivotColumns = STUFF((SELECT ',' + QUOTENAME(SaleYear)
                              FROM #SalesData
                              GROUP BY SaleYear
                              ORDER BY SaleYear
                              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''); -- Corrected: Removed .P

-- Construct the dynamic SQL query
SET @SQLQuery =
    N'SELECT ''Exmpl12 - Dynamic PIVOT'' AS ExampleInfo, SaleQuarter, ' + @PivotColumns + N'
      FROM
          (SELECT SaleYear, SaleQuarter, Amount FROM #SalesData) AS SourceData
      PIVOT
          (
              SUM(Amount)
              FOR SaleYear IN (' + @PivotColumns + N')
          ) AS PivotTable
      ORDER BY SaleQuarter;';

-- Execute the dynamic query

EXEC sp_executesql @SQLQuery;




-- Example 13: UNPIVOT
--             Rotate columns into rows. Convert the pivoted data back to rows.
--             Assumes the pivoted structure from Example 11.
SELECT
    'Exmpl13 - UNPIVOT Example' AS ExampleInfo, -- Combined Example Number and Description
    SaleYear, SaleQuarter, Amount
FROM
   (SELECT SaleYear, [Q1], [Q2], [Q3], [Q4]
    FROM
        (SELECT SaleYear, SaleQuarter, Amount FROM #SalesData) AS SourceData
    PIVOT
        (
            SUM(Amount) FOR SaleQuarter IN ([Q1], [Q2], [Q3], [Q4])
        ) AS PivotTable
   ) AS PivotResult
UNPIVOT
   (
    Amount FOR SaleQuarter IN ([Q1], [Q2], [Q3], [Q4]) -- Specify the columns to unpivot and the new column names
   ) AS UnpivotResult;

DROP TABLE #SalesData; -- Clean up temp table




-- --- STRING AGGREGATION (STUFF + FOR XML PATH) EXAMPLE ---

-- Example 14: Concatenate product names for each order
--             Uses STUFF and FOR XML PATH for string aggregation (like GROUP_CONCAT).
SELECT
    'Exmpl14 - String Aggregation' AS ExampleInfo, -- Combined Example Number and Description
    o.OrderID,
    STUFF(
        (SELECT ', ' + p.ProductName
         FROM #Orders sub_o
         JOIN #Products p ON sub_o.ProductID = p.ProductID
         WHERE sub_o.OrderID = o.OrderID -- Correlate subquery to the outer query
         FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)') -- Generate XML and extract value
        , 1, 2, '' -- Remove the leading comma and space
    ) AS ProductsInOrder
FROM #Orders o
GROUP BY o.OrderID -- Group by OrderID to get one row per order
ORDER BY o.OrderID
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- --- PATTERN MATCHING (LIKE) EXAMPLE ---
-- Note: MS SQL Server does not have native support for full Regular Expressions.
-- The LIKE operator is the primary built-in tool for pattern matching.
-- For complex regex, you would typically use CLR Integration or process data externally.

-- Example 15: More complex LIKE patterns
SELECT
    'Exmpl15 - Pattern Matching' AS ExampleInfo, -- Combined Example Number and Description
    CustomerID,
    CustomerName,
    Email
FROM #Customers
WHERE
    -- Emails starting with 'c' or 'C', followed by any number of characters, ending with '.com'
    Email LIKE '[cC]%[.]com'
    OR -- OR emails containing exactly 5 characters before '@'
    Email LIKE '_____@%';




-- --- MODULO OPERATOR EXAMPLE ---

-- Example 16: Find CustomerIDs that are odd or even
SELECT
    'Exmpl16 - Modulo Operator' AS ExampleInfo, -- Combined Example Number and Description
    CustomerID,
    CustomerName,
    CustomerID % 2 AS ModuloResult,
    IIF(CustomerID % 2 = 0, 'Even', 'Odd') AS CustomerType -- Using IIF for conditional logic
FROM #Customers
ORDER BY CustomerID
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- --- ADVANCED DATE FUNCTIONS EXAMPLES ---

-- Example 17: Extracting different date parts and formats
SELECT
    'Exmpl17 - Date Functions' AS ExampleInfo, -- Combined Example Number and Description
    OrderDate,
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    DAY(OrderDate) AS OrderDay,
    DATEPART(quarter, OrderDate) AS OrderQuarterNumber, -- Quarter number (1-4)
    DATEPART(week, OrderDate) AS OrderWeekNumber,     -- Week number (depends on @@DATEFIRST)
    DATEPART(iso_week, OrderDate) AS OrderISOWeekNumber, -- ISO 8601 week number

    -- Examples using DATEPART and string concatenation for numerical formats
    -- Format as-QN (e.g., 2023-Q1)
    CAST(YEAR(OrderDate) AS VARCHAR(4)) + '-Q' + CAST(DATEPART(quarter, OrderDate) AS VARCHAR(1)) AS YearQuarter_Numerical,

    -- Format as-MM (e.g., 2023-01) - using FORMAT is appropriate here
    FORMAT(OrderDate, 'yyyy-MM') AS YearMonth_Numerical,

    -- Format as-WW (e.g., 2023-01) - ISO week, zero-padded
    CAST(YEAR(OrderDate) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(DATEPART(iso_week, OrderDate) AS VARCHAR(2)), 2) AS YearWeekISO_Numerical

FROM #Orders
ORDER BY OrderDate
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- Example 18: Period-to-Date Calculations (YTD, MTD, WTD)
--             Requires a fixed reference date (GETDATE() in this case).
--             Using Window Functions for YTD/MTD/WTD within a single query result.
WITH OrderDates AS (
    SELECT
        OrderID,
        CustomerID,
        OrderDate,
        TotalAmount,
        CAST(GETDATE() AS DATE) AS Today -- Get today's date once
    FROM #Orders
)
SELECT
    'Exmpl18 - Period-to-Date' AS ExampleInfo, -- Combined Example Number and Description
    OrderID,
    CustomerID,
    OrderDate,
    TotalAmount,
    SUM(TotalAmount) OVER (PARTITION BY CustomerID, YEAR(OrderDate) ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CustomerYTD, -- YTD per customer
    SUM(TotalAmount) OVER (PARTITION BY CustomerID, YEAR(OrderDate), MONTH(OrderDate) ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CustomerMTD, -- MTD per customer
    SUM(TotalAmount) OVER (PARTITION BY CustomerID, YEAR(OrderDate), DATEPART(iso_week, OrderDate) ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CustomerWTD -- WTD per customer (ISO week)
FROM OrderDates
WHERE OrderDate >= DATEADD(year, -1, Today) -- Filter for recent orders to make YTD/MTD/WTD meaningful
ORDER BY CustomerID, OrderDate
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY;




-- --- RECURSIVE CTE EXAMPLE ---

-- Example 19: Simple Recursive CTE (e.g., generating a series of dates)
--             Useful for hierarchical data or generating sequences.
WITH DateSeries AS (
    -- Anchor member: the starting point
    SELECT
        'Exmpl19 - Recursive CTE' AS ExampleInfo, -- Combined Example Number and Description
        CAST('2023-01-01' AS DATE) AS SeriesDate
    UNION ALL
    -- Recursive member: generates the next date
    SELECT
        'Exmpl19 - Recursive CTE' AS ExampleInfo, -- Combined Example Number and Description
        DATEADD(day, 1, SeriesDate)
    FROM DateSeries
    WHERE SeriesDate < '2023-01-10' -- Termination condition
)
-- Final SELECT statement to return the result
SELECT ExampleInfo, SeriesDate
FROM DateSeries
OPTION (MAXRECURSION 100);




-- --- JSON HANDLING EXAMPLES ---
-- Note: MS SQL Server 2016 and later have built-in JSON functions.

-- Example 20: Formatting query results as JSON
--             FOR JSON PATH creates a JSON array of objects.
--             Adding ExampleInfo is less standard here as it's JSON output,
--             but we can include it in the outer select for consistency.
SELECT
    'Exmpl20 - Format as JSON' AS ExampleInfo, -- Combined Example Number and Description
    c.CustomerID,
    c.CustomerName,
    c.City,
    (SELECT o.OrderID, o.OrderDate, o.TotalAmount
     FROM #Orders o
     WHERE o.CustomerID = c.CustomerID
     FOR JSON PATH) AS CustomerOrders -- Subquery to get orders for each customer as JSON array
FROM #Customers c
WHERE c.CustomerID <= 5 -- Limit output
FOR JSON PATH; -- Format the main query result as JSON array




-- Example 21: Reading data from a JSON string (OPENJSON)
--             Assume you have a JSON string representing an order.
DECLARE @json NVARCHAR(MAX);
SET @json = N'{"OrderID": 1001, "CustomerID": 5, "OrderDate": "2024-01-15", "TotalAmount": 123.45, "Items": [{"ProductID": 1, "Quantity": 2}, {"ProductID": 3, "Quantity": 1}]}';

SELECT
    'Exmpl21 - Read JSON' AS ExampleInfo, -- Combined Example Number and Description
    OrderID,
    CustomerID,
    OrderDate,
    TotalAmount
FROM OPENJSON(@json)
WITH (
    OrderID INT '$.OrderID',
    CustomerID INT '$.CustomerID',
    OrderDate DATE '$.OrderDate',
    TotalAmount DECIMAL(10, 2) '$.TotalAmount'
);




-- Example 22: Reading nested JSON (Items array)
SELECT
    'Exmpl22 - Read Nested JSON' AS ExampleInfo, -- Combined Example Number and Description
    OrderID,
    Item.ProductID,
    Item.Quantity
FROM OPENJSON(@json)
WITH (
    OrderID INT '$.OrderID',
    Items NVARCHAR(MAX) '$.Items' AS JSON -- Define 'Items' as JSON
)
CROSS APPLY OPENJSON(Items)
WITH (
    ProductID INT '$.ProductID',
    Quantity INT '$.Quantity'
) AS Item;




-- --- DYNAMIC SQL EXAMPLE ---
-- Note: Dynamic SQL is used when the full query string is not known until runtime,
--       e.g., when column names or table names are parameters.
--       Use with caution due to potential SQL Injection risks if inputs are not sanitized.

-- Example 23: Select data from a table name provided as a variable
DECLARE @TableName NVARCHAR(128) = '#Customers';
DECLARE @ColumnList NVARCHAR(MAX) = 'CustomerID, CustomerName, City';
DECLARE @WhereClause NVARCHAR(MAX) = 'City = ''New York'''; -- Note: Single quotes inside string must be doubled

DECLARE @DynamicSQL NVARCHAR(MAX);
-- Construct the dynamic SQL query including the example number and description
SET @DynamicSQL = N'SELECT ''Exmpl23 - Dynamic SQL'' AS ExampleInfo, ' + @ColumnList + N' FROM ' + @TableName + N' WHERE ' + @WhereClause + N';';


EXEC sp_executesql @DynamicSQL;




-- Example 24: Dynamic SQL with parameters (safer against SQL Injection)
DECLARE @TargetCity NVARCHAR(50) = 'London';
SET @DynamicSQL = N'SELECT ''Exmpl24 - Dynamic SQL Param'' AS ExampleInfo, CustomerID, CustomerName, City FROM #Customers WHERE City = @CityParam;';


EXEC sp_executesql @DynamicSQL, N'@CityParam NVARCHAR(50)', @TargetCity;




-- --- OTHER USEFUL FUNCTIONS EXAMPLES ---

-- Example 25: Conditional Logic (IIF, CHOOSE)
SELECT
    'Exmpl25 - Conditional Logic' AS ExampleInfo, -- Combined Example Number and Description
    OrderID,
    TotalAmount,
    IIF(TotalAmount > 500, 'High Value', 'Standard Value') AS ValueCategory, -- Simple IF-THEN-ELSE
    CHOOSE(CAST(DATEPART(month, OrderDate) AS INT), 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec') AS OrderMonthName -- Choose value based on index
FROM #Orders
ORDER BY OrderID
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;




-- Example 26: TRY_CAST and TRY_CONVERT
--             Attempt conversion and return NULL if it fails, instead of raising an error.
SELECT
    'Exmpl26 - Safe Conversion' AS ExampleInfo, -- Combined Example Number and Description
    '123' AS StringValue,
    TRY_CAST('123' AS INT) AS TryCastToInt, -- Successful conversion
    TRY_CAST('abc' AS INT) AS TryCastToInt_Fail, -- Fails, returns NULL
    TRY_CONVERT(DATE, '2024-10-26') AS TryConvertToDate, -- Successful conversion
    TRY_CONVERT(DATE, 'invalid-date') AS TryConvertToDate_Fail;






-- Clean up the temporary tables at the end of the script

DROP TABLE #Customers;
DROP TABLE #Orders;
DROP TABLE #Products;
IF OBJECT_ID('tempdb..#SalesData') IS NOT NULL
    DROP TABLE #SalesData;