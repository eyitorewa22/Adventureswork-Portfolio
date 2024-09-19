	--EMPLOYEE ANALYSIS
--Employee Sales Performance by Quarter
SELECT 
    p.FirstName + ' ' + p.LastName AS Employee_Name,
    DATEPART(YEAR, soh.OrderDate) AS SalesYear,
    DATEPART(QUARTER, soh.OrderDate) AS SalesQuarter,
    SUM(sod.LineTotal) AS TotalSales
FROM 
    Sales.SalesOrderHeader soh
JOIN 
    Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN 
    Sales.SalesPerson sp ON soh.SalesPersonID = sp.BusinessEntityID
JOIN 
    HumanResources.Employee e ON sp.BusinessEntityID = e.BusinessEntityID
JOIN 
    Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
GROUP BY 
    p.FirstName, p.LastName, DATEPART(YEAR, soh.OrderDate), DATEPART(QUARTER, soh.OrderDate)
ORDER BY 
    SalesYear, SalesQuarter, TotalSales DESC;

--Employee overall Performance
WITH SalespersonPerformance AS (
    SELECT sp.BusinessEntityID, p.FirstName + ' ' + p.LastName AS SalespersonName, SUM(soh.TotalDue) AS TotalSales
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesPerson sp ON soh.SalesPersonID = sp.BusinessEntityID
    JOIN Person.Person p ON sp.BusinessEntityID = p.BusinessEntityID
    GROUP BY sp.BusinessEntityID, p.FirstName, p.LastName
)
SELECT SalespersonName, TotalSales
FROM SalespersonPerformance
ORDER BY TotalSales DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

--b
WITH EmployeeOrders AS (
    SELECT p.FirstName + ' ' + p.LastName AS EmployeeName, COUNT(soh.SalesOrderID) AS NumberOfOrders
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesPerson sp ON soh.SalesPersonID = sp.BusinessEntityID
    JOIN Person.Person p ON sp.BusinessEntityID = p.BusinessEntityID
    GROUP BY p.FirstName, p.LastName
)
SELECT EmployeeName, NumberOfOrders
FROM EmployeeOrders
ORDER BY NumberOfOrders DESC;




--PRODUCT ANALYSIS

--product that has not been sold in the past 1 year
WITH RecentProductSales AS (
    SELECT p.ProductID, p.Name AS ProductName, MAX(soh.OrderDate) AS LastSaleDate
    FROM Sales.SalesOrderDetail sod
    JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
    JOIN Production.Product p ON sod.ProductID = p.ProductID
    GROUP BY p.ProductID, p.Name
)
SELECT ProductName, LastSaleDate
FROM RecentProductSales
WHERE LastSaleDate < DATEADD(YEAR, -1, GETDATE())
ORDER BY LastSaleDate;


--product profitability
WITH ProductProfit AS (
    SELECT p.ProductID, p.Name AS ProductName, 
           SUM(sod.LineTotal) AS TotalRevenue, 
           SUM(sod.OrderQty * p.StandardCost) AS TotalCost
    FROM Sales.SalesOrderDetail sod
    JOIN Production.Product p ON sod.ProductID = p.ProductID
    GROUP BY p.ProductID, p.Name
)
SELECT ProductName, TotalRevenue - TotalCost AS TotalProfit
FROM ProductProfit
ORDER BY TotalProfit DESC;


--Product and Inventory Analysis 
--top 10 fast selling product
SELECT p.Name AS ProductName, 
       SUM(sod.OrderQty) AS TotalQuantitySold
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY TotalQuantitySold DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

--inventory status
SELECT p.Name AS ProductName, 
       SUM(pi.Quantity) AS TotalQuantityInStock
FROM Production.ProductInventory pi
JOIN Production.Product p ON pi.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY TotalQuantityInStock DESC;

--Discounted Product Analysis
SELECT 
    P.ProductID,
    P.Name AS ProductName,
    Subquery.TotalSales AS TotalSalesRevenue,
    Subquery.TotalDiscount AS TotalDiscountAmount,
    CASE 
        WHEN Subquery.TotalSales = 0 THEN 0
        ELSE (Subquery.TotalDiscount / Subquery.TotalSales) * 100
    END AS DiscountPercentage
FROM 
    Production.Product P
INNER JOIN 
    (
        -- Subquery to calculate total sales and total discount for each product
        SELECT 
            SOD.ProductID,
            SUM(SOD.UnitPrice * SOD.OrderQty) AS TotalSales,
            SUM(SOD.UnitPriceDiscount * SOD.OrderQty) AS TotalDiscount
        FROM 
            Sales.SalesOrderDetail SOD
        INNER JOIN 
            Sales.SalesOrderHeader SOH ON SOD.SalesOrderID = SOH.SalesOrderID
        WHERE 
            SOD.UnitPriceDiscount > 0 -- Only consider discounted sales
        GROUP BY 
            SOD.ProductID
    ) Subquery ON P.ProductID = Subquery.ProductID
ORDER BY 
    DiscountPercentage DESC;


--SALES ANALYSIS

--total sales by year
WITH SalesByYear AS (
    SELECT YEAR(OrderDate) AS SalesYear, TotalDue
    FROM Sales.SalesOrderHeader
)
SELECT SalesYear, SUM(TotalDue) AS TotalSales
FROM SalesByYear
GROUP BY SalesYear
ORDER BY SalesYear;

--Sales by Product Category
SELECT pc.Name AS ProductCategory, 
       SUM(sod.LineTotal) AS Sales
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.Name
ORDER BY Sales DESC;

--Sales by Territory
WITH TerritorySales AS (
    SELECT st.Name AS Territory, soh.TotalDue
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
)
SELECT Territory, SUM(TotalDue) AS TotalSales
FROM TerritorySales
GROUP BY Territory
ORDER BY TotalSales DESC;

--CUSTOMERS' BEHAVIOUR ANALYSIS
--top 10 customers
WITH CustomerSpending AS (
    SELECT c.CustomerID, p.FirstName + ' ' + p.LastName AS FullName, SUM(soh.TotalDue) AS TotalSpent
    FROM Sales.Customer c
    JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
    JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
    GROUP BY c.CustomerID, p.FirstName, p.LastName
)
SELECT CustomerID, FullName, TotalSpent
FROM CustomerSpending
ORDER BY TotalSpent DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

--Customer Purchases by Territory
WITH TerritoryCustomers AS (
    SELECT st.Name AS Territory, c.CustomerID, SUM(soh.TotalDue) AS TotalSpent
    FROM Sales.Customer c
    JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
    JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
    GROUP BY st.Name, c.CustomerID
)
SELECT Territory, COUNT(DISTINCT CustomerID) AS NumberOfCustomers, SUM(TotalSpent) AS TotalSpent
FROM TerritoryCustomers
GROUP BY Territory
ORDER BY TotalSpent DESC;

--Customers Without Recent Purchases (last 12 months)
WITH RecentCustomers AS (
    SELECT p.FirstName + ' ' + p.LastName AS FullName, MAX(soh.OrderDate) AS LastPurchaseDate
    FROM Sales.Customer c
    JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
    JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
    GROUP BY p.FirstName, p.LastName
)
SELECT FullName, LastPurchaseDate
FROM RecentCustomers
WHERE LastPurchaseDate < DATEADD(YEAR, -1, GETDATE())
ORDER BY LastPurchaseDate;

--Average Order Value by Customer
SELECT 
    CustomerID,
    FirstName + ' ' + LastName AS CustomerName,
    (SELECT AVG(OrderTotal)
     FROM (SELECT SUM(sod.LineTotal) AS OrderTotal
           FROM Sales.SalesOrderHeader soh
           JOIN Sales.SalesOrderDetail sod 
           ON soh.SalesOrderID = sod.SalesOrderID
           WHERE soh.CustomerID = c.CustomerID
           GROUP BY soh.SalesOrderID) AS OrderSums) AS AverageOrderValue
FROM 
    Sales.Customer c
JOIN 
    Person.Person p ON c.PersonID = p.BusinessEntityID
ORDER BY 
    AverageOrderValue DESC;

--ORDER ANALYSIS
--Unshipped Orders
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.DueDate,
    soh.ShipDate,
    (SELECT FirstName + ' ' + LastName 
     FROM Person.Person p 
     WHERE p.BusinessEntityID = soh.CustomerID) AS CustomerName,
    (SELECT COUNT(*) 
     FROM Sales.SalesOrderDetail sod 
     WHERE sod.SalesOrderID = soh.SalesOrderID) AS TotalItems
FROM 
    Sales.SalesOrderHeader soh
WHERE 
    soh.ShipDate IS NULL
ORDER BY 
    soh.OrderDate DESC; 

--Average Time(days) to Ship an Order
SELECT 
    CustomerID,
    FirstName + ' ' + LastName AS CustomerName,
    (SELECT AVG(DATEDIFF(DAY, soh.OrderDate, soh.ShipDate))
     FROM Sales.SalesOrderHeader soh
     WHERE soh.CustomerID = c.CustomerID 
     AND soh.ShipDate IS NOT NULL) AS AvgTimeToShip
FROM 
    Sales.Customer c
JOIN 
    Person.Person p ON c.PersonID = p.BusinessEntityID
ORDER BY 
    AvgTimeToShip DESC;

--VENDOR ANALYSIS
--Vendors Offering Products Priced Above the Average
SELECT 
    V.BusinessEntityID,
    PV.ProductID,
    PV.StandardPrice,
    V.Name AS VendorName
FROM 
    Purchasing.ProductVendor PV
INNER JOIN 
    Purchasing.Vendor V ON PV.BusinessEntityID = V.BusinessEntityID
WHERE 
    PV.StandardPrice > 
    (
        -- Subquery to calculate the average StandardPrice of all products
        SELECT AVG(PV2.StandardPrice)
        FROM 
            Purchasing.ProductVendor PV2
    )
ORDER BY 
    PV.StandardPrice DESC;









