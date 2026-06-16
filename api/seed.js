const db = require('./config/db');
const bcrypt = require('bcryptjs');

async function seed() {
    try {
        console.log('Seeding started...');
        
        // Disable foreign key checks for clean seeding if we want to truncate, 
        // but here we just use INSERT IGNORE to prevent duplicate errors.

        // 1. Roles
        await db.execute("INSERT IGNORE INTO Role (Id, Name) VALUES (1, 'student'), (2, 'teacher'), (3, 'admin')");
        
        // 2. Gender
        await db.execute("INSERT IGNORE INTO Gender (Id, Name) VALUES (1, 'Laki-laki'), (2, 'Perempuan')");
        
        // 3. Religion
        await db.execute("INSERT IGNORE INTO Religion (Id, Name) VALUES (1, 'Islam'), (2, 'Kristen'), (3, 'Katolik'), (4, 'Hindu'), (5, 'Buddha'), (6, 'Konghucu')");
        
        // 4. Major
        await db.execute("INSERT IGNORE INTO Major (Id, Name) VALUES (1, 'IPA'), (2, 'IPS'), (3, 'Bahasa'), (4, 'RPL'), (5, 'MLOG'), (6, 'DKV'), (7, 'Akuntansi')");
        
        // 5. School
        await db.execute("INSERT IGNORE INTO School (Id, SchoolName, SchoolCode, Address) VALUES (1, 'SMA Negeri 1 EduVaults', 'SCH001', 'Jl. Pendidikan No 1')");

        // Use a default hashed password for all dummy users: "password123"
        const defaultPassword = await bcrypt.hash('password123', 10);

        // 6. Users
        const users = [
            // Teacher
            [1, 'pakbudi', 'Budi Santoso', 'budi@eduvaults.com', 2, 1, 1, 'O', null, null, '1980-05-10', 'Jl. Guru No 1', '081234567890', defaultPassword, null, 1],
            // Student 1
            [2, 'andi', 'Andi Pratama', 'andi@eduvaults.com', 1, 1, 1, 'A', 1001, 2001, '2005-08-15', 'Jl. Siswa No 1', '081234567891', defaultPassword, 1, 1],
            // Student 2
            [3, 'siti', 'Siti Aminah', 'siti@eduvaults.com', 1, 2, 1, 'B', 1002, 2002, '2005-09-20', 'Jl. Siswa No 2', '081234567892', defaultPassword, 2, 1]
        ];

        for (const u of users) {
            await db.execute(`
                INSERT IGNORE INTO User (Id, Username, Fullname, Email, RoleId, GenderId, ReligionId, BloodType, NIS, NISN, BirthDate, Address, PhoneNumber, Password, MajorId, IsActive)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `, u);
        }

        // 7. SchoolMember
        const schoolMembers = [
            [1, 1, 1, 2, null, null, null, null],
            [2, 1, 2, 1, 1001, 2001, 1, null],
            [3, 1, 3, 1, 1002, 2002, 2, null]
        ];
        for (const sm of schoolMembers) {
            await db.execute(`INSERT IGNORE INTO SchoolMember (Id, SchoolId, UserId, MemberRoleId, NIS, NISN, MajorId, ClassId) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, sm);
        }

        // 8. Classes
        await db.execute(`INSERT IGNORE INTO Classes (Id, ClassName, Description, TeacherId, SchoolId) VALUES (1, 'Matematika - MTH01', 'Kelas Matematika X MIPA', 1, 1)`);
        await db.execute(`INSERT IGNORE INTO Classes (Id, ClassName, Description, TeacherId, SchoolId) VALUES (2, 'Biologi - BIO01', 'Kelas Biologi X MIPA', 1, 1)`);

        // 9. ClassMember
        await db.execute(`INSERT IGNORE INTO ClassMember (Id, ClassId, UserId, MemberRoleId, SchoolId) VALUES (1, 1, 2, 1, 1)`); // Andi in Math
        await db.execute(`INSERT IGNORE INTO ClassMember (Id, ClassId, UserId, MemberRoleId, SchoolId) VALUES (2, 1, 3, 1, 1)`); // Siti in Math

        // 10. Announcement
        await db.execute(`INSERT IGNORE INTO Announcement (Id, UserId, PostContent, ClassId, SchoolId) VALUES (1, 1, 'Selamat datang di kelas Matematika! Jangan lupa baca silabus di bagian materi.', 1, 1)`);
        await db.execute(`INSERT IGNORE INTO Announcement (Id, UserId, PostContent, ClassId, SchoolId) VALUES (2, 1, 'Besok kita akan ada kuis singkat ya.', 1, 1)`);

        // 11. Assignments
        await db.execute(`INSERT IGNORE INTO Assignments (Id, ClassId, Title, Description, DueDate, CreatedById, SchoolId) VALUES (1, 1, 'Tugas Aljabar 1', 'Kerjakan LKS halaman 10-15', '2026-12-31 23:59:00', 1, 1)`);
        await db.execute(`INSERT IGNORE INTO Assignments (Id, ClassId, Title, Description, DueDate, CreatedById, SchoolId) VALUES (2, 1, 'Project Tengah Semester', 'Buat makalah penerapan aljabar', '2026-10-31 23:59:00', 1, 1)`);

        // 12. Submissions
        await db.execute(`INSERT IGNORE INTO Submissions (Id, AssignmentId, StudentId, AnswerText, FilePath, Grade, Feedback, SchoolId) VALUES (1, 1, 2, 'Ini jawaban saya pak', '/dummy/path.pdf', 90, 'Kerja bagus Andi!', 1)`);

        // 13. Materials
        await db.execute(`INSERT IGNORE INTO Materials (Id, ClassId, Title, FilePath, UploadedById, SchoolId) VALUES (1, 1, 'Materi Aljabar Dasar PDF', '/dummy/materi.pdf', 1, 1)`);

        // 14. Schedule
        await db.execute(`INSERT IGNORE INTO Schedule (Id, SchoolId, ClassId, UserId, Title, ScheduleType, DayOfWeek, StartTime, EndTime, Room) VALUES (1, 1, 1, 1, 'Matematika Wajib', 'regular', 'Senin', '08:00:00', '10:00:00', 'Ruang 101')`);

        // 15. EkskulSchedule
        await db.execute(`INSERT IGNORE INTO EkskulSchedule (Id, SchoolId, EkskulName, Description, CoachUserId, DayOfWeek, StartTime, EndTime, Room) VALUES (1, 1, 'Pramuka', 'Ekskul Pramuka Wajib Kelas X', 1, 'Jumat', '15:00:00', '17:00:00', 'Lapangan Utama')`);

        // 16. EventSchedule
        await db.execute(`INSERT IGNORE INTO EventSchedule (Id, SchoolId, Title, Description, EventDate, StartTime, EndTime, Room, DressCode, CreatedByUserId) VALUES (1, 1, 'Upacara Bendera', 'Upacara Rutin Hari Senin', '2026-08-17', '07:00:00', '08:00:00', 'Lapangan Utama', 'Seragam Putih Abu-abu', 1)`);

        // 17. ExamGrid
        await db.execute(`INSERT IGNORE INTO ExamGrid (Id, SchoolId, ClassId, CreatedByUserId, Title, Subject, ExamDate, StartTime, EndTime, Room, RequiredApps, Rules, ExamType) VALUES (1, 1, 1, 1, 'Ujian Tengah Semester', 'Matematika', '2026-10-10', '08:00:00', '10:00:00', 'Lab Komputer', 'Safe Exam Browser', 'Dilarang menyontek', 'UTS')`);

        // 18. News
        await db.execute(`INSERT IGNORE INTO News (Id, SchoolId, UserId, Title, Content) VALUES (1, 1, 1, 'Peringatan Hari Kemerdekaan', 'Sekolah akan mengadakan lomba 17 Agustus pada hari jumat mendatang. Mohon seluruh siswa berpartisipasi.')`);

        // 19. NewsMedia
        await db.execute(`INSERT IGNORE INTO NewsMedia (Id, NewsId, MediaType, FileName, FilePath) VALUES (1, 1, 'image', 'lomba17an.jpg', '/dummy/lomba17an.jpg')`);

        console.log('✅ Dummy data seeded successfully across all tables!');
    } catch (error) {
        console.error('❌ Error seeding data:', error);
    } finally {
        process.exit();
    }
}

seed();
