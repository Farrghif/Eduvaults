-- Create database
CREATE DATABASE IF NOT EXISTS eduvaults;
USE eduvaults;

-- Disable foreign key checks temporarily during creation to avoid order issues
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Gender
CREATE TABLE IF NOT EXISTS Gender (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
);

-- 2. Religion
CREATE TABLE IF NOT EXISTS Religion (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
);

-- 3. Major
CREATE TABLE IF NOT EXISTS Major (
    Id INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
);

-- 4. Role
CREATE TABLE IF NOT EXISTS Role (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
);

-- 5. School
CREATE TABLE IF NOT EXISTS School (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    SchoolName VARCHAR(100) NOT NULL,
    SchoolCode VARCHAR(10) NOT NULL UNIQUE,
    Address VARCHAR(200) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. User
CREATE TABLE IF NOT EXISTS User (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(100) NOT NULL,
    Fullname VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    RoleId INT NOT NULL,
    GenderId INT NOT NULL,
    ReligionId INT NOT NULL,
    BloodType VARCHAR(10) NOT NULL,
    NIS INT NULL,
    NISN INT NULL,
    BirthDate DATE NOT NULL,
    Address VARCHAR(200) NOT NULL,
    PhoneNumber VARCHAR(200) NOT NULL,
    Password VARCHAR(200) NOT NULL,
    MajorId INT NULL,
    IsActive TINYINT(1) NOT NULL DEFAULT 1,
    ProfileImage LONGBLOB NULL,
    FOREIGN KEY (GenderId) REFERENCES Gender(Id),
    FOREIGN KEY (ReligionId) REFERENCES Religion(Id),
    FOREIGN KEY (MajorId) REFERENCES Major(Id),
    FOREIGN KEY (RoleId) REFERENCES Role(Id)
);

-- 7. Classes
CREATE TABLE IF NOT EXISTS Classes (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    ClassName VARCHAR(100) NOT NULL,
    Description VARCHAR(500) NOT NULL,
    TeacherId INT NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SchoolId INT NOT NULL,
    UNIQUE (SchoolId, ClassName),
    FOREIGN KEY (SchoolId) REFERENCES School(Id),
    FOREIGN KEY (TeacherId) REFERENCES User(Id)
);

-- 8. ClassMember
CREATE TABLE IF NOT EXISTS ClassMember (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    ClassId INT NOT NULL,
    UserId INT NOT NULL,
    MemberRoleId INT NOT NULL,
    SchoolId INT NOT NULL,
    FOREIGN KEY (ClassId) REFERENCES Classes(Id),
    FOREIGN KEY (UserId) REFERENCES User(Id),
    FOREIGN KEY (MemberRoleId) REFERENCES Role(Id),
    FOREIGN KEY (SchoolId) REFERENCES School(Id)
);

-- 9. Announcement
CREATE TABLE IF NOT EXISTS Announcement (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    UserId INT NOT NULL,
    PostContent VARCHAR(1067) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ClassId INT NULL,
    SchoolId INT NULL,
    FOREIGN KEY (UserId) REFERENCES User(Id),
    FOREIGN KEY (ClassId) REFERENCES Classes(Id),
    FOREIGN KEY (SchoolId) REFERENCES School(Id)
);

-- 10. Assignments
CREATE TABLE IF NOT EXISTS Assignments (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    ClassId INT NOT NULL,
    Title VARCHAR(100) NOT NULL,
    Description VARCHAR(100) NOT NULL,
    FilePath VARCHAR(750) NULL,
    DueDate DATETIME NOT NULL,
    CreatedById INT NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SchoolId INT NOT NULL,
    FOREIGN KEY (ClassId) REFERENCES Classes(Id),
    FOREIGN KEY (CreatedById) REFERENCES User(Id),
    FOREIGN KEY (SchoolId) REFERENCES School(Id)
);

-- 11. Submissions
CREATE TABLE IF NOT EXISTS Submissions (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    AssignmentId INT NOT NULL,
    StudentId INT NOT NULL,
    AnswerText VARCHAR(350) NOT NULL,
    FilePath VARCHAR(750) NOT NULL,
    SubmittedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Grade INT NULL,
    Feedback VARCHAR(500) NOT NULL,
    SchoolId INT NOT NULL,
    FOREIGN KEY (AssignmentId) REFERENCES Assignments(Id),
    FOREIGN KEY (StudentId) REFERENCES User(Id),
    FOREIGN KEY (SchoolId) REFERENCES School(Id)
);

-- 12. EkskulSchedule
CREATE TABLE IF NOT EXISTS EkskulSchedule (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    SchoolId INT NOT NULL,
    EkskulName VARCHAR(100) NOT NULL,
    Description VARCHAR(255) NULL,
    CoachUserId INT NULL,
    DayOfWeek VARCHAR(20) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    Room VARCHAR(100) NULL,
    IsActive TINYINT(1) NULL DEFAULT 1,
    CreatedAt DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (SchoolId) REFERENCES School(Id),
    FOREIGN KEY (CoachUserId) REFERENCES User(Id)
);

-- 13. EventSchedule
CREATE TABLE IF NOT EXISTS EventSchedule (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    SchoolId INT NOT NULL,
    Title VARCHAR(150) NOT NULL,
    Description VARCHAR(500) NULL,
    EventDate DATE NOT NULL,
    StartTime TIME NULL,
    EndTime TIME NULL,
    Room VARCHAR(100) NULL,
    DressCode VARCHAR(150) NULL,
    CreatedByUserId INT NOT NULL,
    CreatedAt DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (SchoolId) REFERENCES School(Id),
    FOREIGN KEY (CreatedByUserId) REFERENCES User(Id)
);

-- 14. ExamGrid
CREATE TABLE IF NOT EXISTS ExamGrid (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    SchoolId INT NOT NULL,
    ClassId INT NOT NULL,
    CreatedByUserId INT NOT NULL,
    Title VARCHAR(150) NOT NULL,
    Subject VARCHAR(100) NOT NULL,
    ExamDate DATE NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    Room VARCHAR(100) NULL,
    RequiredApps VARCHAR(255) NULL,
    Rules VARCHAR(1000) NULL,
    ExamType VARCHAR(50) NULL,
    CreatedAt DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (SchoolId) REFERENCES School(Id),
    FOREIGN KEY (ClassId) REFERENCES Classes(Id),
    FOREIGN KEY (CreatedByUserId) REFERENCES User(Id)
);

-- 15. Materials
CREATE TABLE IF NOT EXISTS Materials (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    ClassId INT NOT NULL,
    Title VARCHAR(300) NOT NULL,
    FilePath VARCHAR(750) NOT NULL,
    UploadedById INT NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SchoolId INT NOT NULL,
    materialsCoverImage LONGBLOB NULL,
    FOREIGN KEY (ClassId) REFERENCES Classes(Id),
    FOREIGN KEY (UploadedById) REFERENCES User(Id),
    FOREIGN KEY (SchoolId) REFERENCES School(Id)
);

-- 16. News
CREATE TABLE IF NOT EXISTS News (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    SchoolId INT NOT NULL,
    UserId INT NOT NULL,
    Title VARCHAR(200) NOT NULL,
    Content LONGTEXT NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (SchoolId) REFERENCES School(Id),
    FOREIGN KEY (UserId) REFERENCES User(Id)
);

-- 17. NewsMedia
CREATE TABLE IF NOT EXISTS NewsMedia (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    NewsId INT NOT NULL,
    MediaType VARCHAR(50) NOT NULL,
    FileName VARCHAR(200) NOT NULL,
    FilePath VARCHAR(500) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ImageNews LONGBLOB NULL,
    FOREIGN KEY (NewsId) REFERENCES News(Id)
);

-- 18. Schedule
CREATE TABLE IF NOT EXISTS Schedule (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    SchoolId INT NOT NULL,
    ClassId INT NOT NULL,
    UserId INT NOT NULL,
    Title VARCHAR(100) NOT NULL,
    ScheduleType VARCHAR(50) NOT NULL,
    DayOfWeek VARCHAR(20) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    Room VARCHAR(100) NULL,
    CreatedAt DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (SchoolId) REFERENCES School(Id),
    FOREIGN KEY (ClassId) REFERENCES Classes(Id),
    FOREIGN KEY (UserId) REFERENCES User(Id)
);

-- 19. SchoolMember
CREATE TABLE IF NOT EXISTS SchoolMember (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    SchoolId INT NOT NULL,
    UserId INT NOT NULL,
    MemberRoleId INT NOT NULL,
    NIS INT NULL,
    NISN INT NULL,
    MajorId INT NULL,
    ClassId INT NULL,
    IsVerified TINYINT(1) NOT NULL DEFAULT 0,
    JoinedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (SchoolId) REFERENCES School(Id),
    FOREIGN KEY (UserId) REFERENCES User(Id),
    FOREIGN KEY (MemberRoleId) REFERENCES Role(Id),
    FOREIGN KEY (MajorId) REFERENCES Major(Id),
    FOREIGN KEY (ClassId) REFERENCES Classes(Id)
);

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- Insert default essential records
INSERT IGNORE INTO Gender (Id, Name) VALUES (1, 'Laki-laki'), (2, 'Perempuan');
INSERT IGNORE INTO Religion (Id, Name) VALUES (1, 'Islam'), (2, 'Kristen'), (3, 'Katolik'), (4, 'Hindu'), (5, 'Buddha'), (6, 'Konghucu');
INSERT IGNORE INTO Role (Id, Name) VALUES (1, 'student'), (2, 'teacher'), (3, 'admin');
INSERT IGNORE INTO School (Id, SchoolName, SchoolCode, Address) VALUES (1, 'Default School', 'SCH001', 'Jl. Pendidikan No 1');
