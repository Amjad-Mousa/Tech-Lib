SQL Commands:

DB_Creation:
CREATE DATABASE [Tech-Lib];
GO

Tables_Creation:

CREATE TABLE Books (
    BookID INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(200) NOT NULL,
    Author NVARCHAR(150) NOT NULL,
    ISBN NVARCHAR(20) UNIQUE NOT NULL,
    PublishedDate DATE,
    Genre NVARCHAR(100),
    ShelfLocation NVARCHAR(50),
    CurrentStatus NVARCHAR(20) CHECK (CurrentStatus IN ('Available', 'Borrowed')) DEFAULT 'Available'
);
GO

CREATE TABLE Borrowers (
    BorrowerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(150) UNIQUE NOT NULL,
    DateOfBirth DATE,
    MembershipDate DATE DEFAULT GETDATE()
);
GO

CREATE TABLE Loans (
    LoanID INT IDENTITY(1,1) PRIMARY KEY,
    BookID INT NOT NULL,
    BorrowerID INT NOT NULL,
    DateBorrowed DATE NOT NULL DEFAULT GETDATE(),
    DueDate DATE NOT NULL,
    DateReturned DATE NULL,

    CONSTRAINT FK_Loans_Books FOREIGN KEY (BookID)
        REFERENCES Books(BookID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT FK_Loans_Borrowers FOREIGN KEY (BorrowerID)
        REFERENCES Borrowers(BorrowerID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);
GO

Data_Seed: 

DECLARE @i INT = 1;
WHILE @i <= 1000
BEGIN
    INSERT INTO Books (Title, Author, ISBN, PublishedDate, Genre, ShelfLocation, CurrentStatus)
    VALUES (
        CONCAT('Book Title ', @i),
        CONCAT('Author ', @i),
        CONCAT('978-0-', FORMAT(@i, '0000000000')),
        DATEADD(DAY, -(@i * 20), GETDATE()),
        CASE 
            WHEN @i % 5 = 0 THEN 'Technology'
            WHEN @i % 5 = 1 THEN 'Science'
            WHEN @i % 5 = 2 THEN 'History'
            WHEN @i % 5 = 3 THEN 'Fiction'
            ELSE 'Programming'
        END,
        CONCAT('SHELF-', (@i % 50) + 1),
        'Available'
    );
    SET @i += 1;
END;
GO

DECLARE @i INT = 1;
SET @i = 1;
WHILE @i <= 1000
BEGIN
    INSERT INTO Borrowers (FirstName, LastName, Email, DateOfBirth, MembershipDate)
    VALUES (
        CONCAT('UserFirst', @i),
        CONCAT('UserLast', @i),
        CONCAT('user', @i, '@techlib.com'),
        DATEADD(YEAR, -20 - (@i % 15), GETDATE()),
        DATEADD(DAY, -(@i * 2), GETDATE())
    );
    SET @i += 1;
END;
GO


DECLARE @i INT = 1;
SET @i = 1;
WHILE @i <= 1000
BEGIN
    DECLARE @BookID INT = ((@i - 1) % 1000) + 1;
    DECLARE @BorrowerID INT = ((@i - 1) % 1000) + 1;
    DECLARE @Borrowed DATE = DATEADD(DAY, -(@i % 200), GETDATE());
    DECLARE @Due DATE = DATEADD(DAY, 14, @Borrowed);
    DECLARE @Returned DATE = CASE WHEN @i % 3 = 0 THEN DATEADD(DAY, 10, @Borrowed) ELSE NULL END;

    INSERT INTO Loans (BookID, BorrowerID, DateBorrowed, DueDate, DateReturned)
    VALUES (@BookID, @BorrowerID, @Borrowed, @Due, @Returned);

    SET @i += 1;
END;
GO


Queries: 


1-SELECT 
    Books.Title,
    Books.Author,
    Loans.DateBorrowed,
    Loans.DueDate,
    Loans.DateReturned
FROM 
    Loans
INNER JOIN Books ON Loans.BookID = Books.BookID
INNER JOIN Borrowers ON Loans.BorrowerID = Borrowers.BorrowerID
WHERE Borrowers.BorrowerID = @BorrowerID;


2-WITH BorrowerStats AS (
    SELECT
        b.BorrowerID,
        b.FirstName,
        b.LastName,
        COUNT(l.LoanID) AS TotalBorrowed,
        SUM(CASE WHEN l.DateReturned IS NULL THEN 1 ELSE 0 END) AS NotReturnedCount
    FROM Borrowers b
    INNER JOIN Loans l ON b.BorrowerID = l.BorrowerID
    GROUP BY
        b.BorrowerID,
        b.FirstName,
        b.LastName
)
SELECT
    BorrowerID,
    FirstName,
    LastName,
    TotalBorrowed,
    NotReturnedCount
FROM BorrowerStats
WHERE TotalBorrowed >= 2
  AND NotReturnedCount = TotalBorrowed; 


3-WITH BorrowerFrequency AS (
    SELECT 
        b.BorrowerID,
        b.FirstName,
        b.LastName,
        COUNT(l.LoanID) AS TotalBorrowed
    FROM Borrowers b
    LEFT JOIN Loans l ON b.BorrowerID = l.BorrowerID
    GROUP BY 
        b.BorrowerID,
        b.FirstName,
        b.LastName
)
SELECT 
    BorrowerID,
    FirstName,
    LastName,
    TotalBorrowed,
    RANK() OVER (ORDER BY TotalBorrowed DESC) AS BorrowingRank
FROM BorrowerFrequency;

4-DECLARE @TargetMonth INT = 10
DECLARE @TargetYear INT = 2025

WITH GenreStats AS (
    SELECT 
        b.Genre,
        COUNT(*) AS BorrowCount
    FROM Loans l
    INNER JOIN Books b ON l.BookID = b.BookID
    WHERE MONTH(l.DateBorrowed) = @TargetMonth
      AND YEAR(l.DateBorrowed) = @TargetYear
    GROUP BY b.Genre
),
RankedGenres AS (
    SELECT 
        Genre,
        BorrowCount,
        RANK() OVER (ORDER BY BorrowCount DESC) AS GenreRank
    FROM GenreStats
)
SELECT Genre, BorrowCount
FROM RankedGenres
WHERE GenreRank = 1

5-CREATE PROCEDURE sp_AddNewBorrower
    @FirstName VARCHAR(50),
    @LastName VARCHAR(50),
    @Email VARCHAR(100),
    @DateOfBirth DATE,
    @MembershipDate DATE
AS
BEGIN
    INSERT INTO Borrowers (FirstName, LastName, Email, DateOfBirth, MembershipDate)
    VALUES (@FirstName, @LastName, @Email, @DateOfBirth, @MembershipDate)
END



6-CREATE FUNCTION fn_CalculateOverdueFees
(
    @LoanID INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Fee DECIMAL(10,2) = 0
    DECLARE @DueDate DATE
    DECLARE @DateReturned DATE
    DECLARE @OverdueDays INT

    SELECT 
        @DueDate = DueDate,
        @DateReturned = DateReturned
    FROM Loans
    WHERE LoanID = @LoanID

    IF @DateReturned IS NULL
        SET @DateReturned = GETDATE()

    SET @OverdueDays = DATEDIFF(DAY, @DueDate, @DateReturned)

    IF @OverdueDays > 0
    BEGIN
        IF @OverdueDays <= 30
            SET @Fee = @OverdueDays * 1
        ELSE
            SET @Fee = (30 * 1) + ((@OverdueDays - 30) * 2)
    END

    RETURN @Fee
END


7-CREATE FUNCTION fn_BookBorrowingFrequency
(
    @BookID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @BorrowCount INT;

    SELECT @BorrowCount = COUNT(*)
    FROM Loans
    WHERE BookID = @BookID;

    RETURN @BorrowCount;
END;


8-SELECT 
    b.BookID,
    b.Title,
    br.BorrowerID,
    br.FirstName,
    br.LastName,
    l.DateBorrowed,
    l.DueDate,
    DATEDIFF(DAY, l.DueDate, GETDATE()) AS DaysOverdue
FROM Loans l
INNER JOIN Books b ON l.BookID = b.BookID
INNER JOIN Borrowers br ON l.BorrowerID = br.BorrowerID
WHERE l.DateReturned IS NULL
  AND DATEDIFF(DAY, l.DueDate, GETDATE()) > 30;


9-SELECT 
    b.Author,
    COUNT(l.LoanID) AS BorrowCount,
    RANK() OVER (ORDER BY COUNT(l.LoanID) DESC) AS AuthorRank
FROM Books b
INNER JOIN Loans l ON b.BookID = l.BookID
GROUP BY b.Author
ORDER BY BorrowCount DESC;


10-WITH BorrowerAge AS (
    SELECT
        BorrowerID,
        DATEDIFF(YEAR, DateOfBirth, GETDATE()) AS Age
    FROM Borrowers
),
BorrowerAgeGroup AS (
    SELECT
        BorrowerID,
        CASE
            WHEN Age BETWEEN 0 AND 10 THEN '0-10'
            WHEN Age BETWEEN 11 AND 20 THEN '11-20'
            WHEN Age BETWEEN 21 AND 30 THEN '21-30'
            WHEN Age BETWEEN 31 AND 40 THEN '31-40'
            WHEN Age BETWEEN 41 AND 50 THEN '41-50'
            ELSE '50+'
        END AS AgeGroup
    FROM BorrowerAge
)
SELECT
    ag.AgeGroup,
    b.Genre,
    COUNT(l.LoanID) AS BorrowCount
FROM BorrowerAgeGroup ag
INNER JOIN Loans l ON ag.BorrowerID = l.BorrowerID
INNER JOIN Books b ON l.BookID = b.BookID
GROUP BY
    ag.AgeGroup,
    b.Genre
ORDER BY
    ag.AgeGroup,
    BorrowCount DESC;


11-CREATE PROCEDURE sp_BorrowedBooksReport
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT
        b.BookID,
        b.Title,
        b.Author,
        b.Genre,
        br.FirstName,
        br.LastName,
        l.DateBorrowed,
        l.DueDate,
        l.DateReturned
    FROM Loans l
    INNER JOIN Books b ON l.BookID = b.BookID
    INNER JOIN Borrowers br ON l.BorrowerID = br.BorrowerID
    WHERE l.DateBorrowed BETWEEN @StartDate AND @EndDate
    ORDER BY l.DateBorrowed, br.LastName, br.FirstName;
END;


12- CREATE TABLE AuditLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    BookID INT NOT NULL,
    StatusChange VARCHAR(50) NOT NULL,
    ChangeDate DATETIME NOT NULL DEFAULT GETDATE()
);


CREATE TRIGGER trg_BookStatusChange
ON Books
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AuditLog (BookID, StatusChange, ChangeDate)
    SELECT 
        i.BookID,
        CONCAT(d.CurrentStatus, ' → ', i.CurrentStatus) AS StatusChange,
        GETDATE()
    FROM inserted i
    INNER JOIN deleted d ON i.BookID = d.BookID
    WHERE d.CurrentStatus <> i.CurrentStatus
      AND (d.CurrentStatus IN ('Available','Borrowed') 
           AND i.CurrentStatus IN ('Available','Borrowed'));
END;


13-CREATE PROCEDURE sp_OverdueBorrowers
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #TempOverdueBorrowers (
        BorrowerID INT PRIMARY KEY,
        FirstName VARCHAR(50),
        LastName VARCHAR(50),
        Email VARCHAR(100)
    );

    INSERT INTO #TempOverdueBorrowers (BorrowerID, FirstName, LastName, Email)
    SELECT DISTINCT
        b.BorrowerID,
        b.FirstName,
        b.LastName,
        b.Email
    FROM Borrowers b
    INNER JOIN Loans l ON b.BorrowerID = l.BorrowerID
    WHERE l.DateReturned IS NULL
      AND l.DueDate < GETDATE();

    SELECT
        t.BorrowerID,
        t.FirstName,
        t.LastName,
        t.Email,
        l.LoanID,
        l.BookID,
        bk.Title,
        l.DateBorrowed,
        l.DueDate
    FROM #TempOverdueBorrowers t
    INNER JOIN Loans l ON t.BorrowerID = l.BorrowerID
    INNER JOIN Books bk ON l.BookID = bk.BookID
    WHERE l.DateReturned IS NULL
      AND l.DueDate < GETDATE()
    ORDER BY t.BorrowerID, l.DueDate;

    DROP TABLE #TempOverdueBorrowers;
END;

