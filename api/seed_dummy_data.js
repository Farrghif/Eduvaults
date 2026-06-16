const db = require('./config/db');

async function seedDummyData() {
    try {
        console.log('Seeding dummy data (excluding users)...');

        // Ensure lookups are present
        await db.execute("INSERT IGNORE INTO Role (Id, Name) VALUES (1, 'student'), (2, 'teacher'), (3, 'admin')");
        await db.execute("INSERT IGNORE INTO Gender (Id, Name) VALUES (1, 'Laki-laki'), (2, 'Perempuan')");
        await db.execute("INSERT IGNORE INTO Religion (Id, Name) VALUES (1, 'Islam'), (2, 'Kristen'), (3, 'Katolik'), (4, 'Hindu'), (5, 'Buddha'), (6, 'Konghucu')");
        await db.execute("INSERT IGNORE INTO Major (Id, Name) VALUES (1, 'IPA'), (2, 'IPS'), (3, 'Bahasa'), (4, 'RPL'), (5, 'MLOG'), (6, 'DKV'), (7, 'Akuntansi')");
        await db.execute("INSERT IGNORE INTO School (Id, SchoolName, SchoolCode, Address) VALUES (1, 'SMA Negeri 1 EduVaults', 'SCH001', 'Jl. Pendidikan No 1')");

        // 1. Fetch existing users to use for relationships
        // Teacher
        const [teachers] = await db.execute(`
            SELECT u.Id FROM User u 
            JOIN Role r ON u.RoleId = r.Id 
            WHERE r.Name = 'teacher' LIMIT 1
        `);
        // Student
        const [students] = await db.execute(`
            SELECT u.Id FROM User u 
            JOIN Role r ON u.RoleId = r.Id 
            WHERE r.Name = 'student' LIMIT 1
        `);

        if (teachers.length === 0 || students.length === 0) {
            console.error('❌ Cannot seed dummy data: Please ensure there is at least ONE active Teacher and ONE active Student registered in the database.');
            process.exit(1);
        }

        const teacherId = teachers[0].Id;
        const studentId = students[0].Id;
        const schoolId = 1;

        console.log(`Using Teacher ID: ${teacherId} and Student ID: ${studentId}`);

        // 2. Create Classes
        const [classResult] = await db.execute(
            `INSERT INTO Classes (ClassName, Description, TeacherId, SchoolId) VALUES (?, ?, ?, ?)`,
            ['Fisika Lanjutan - PHY101', 'Mempelajari konsep fisika modern', teacherId, schoolId]
        );
        const classId = classResult.insertId;

        // 3. Add Student to Class
        await db.execute(
            `INSERT INTO ClassMember (ClassId, UserId, MemberRoleId, SchoolId) VALUES (?, ?, ?, ?)`,
            [classId, studentId, 1, schoolId] // Role 1 is student
        );

        // 4. Create Announcement
        await db.execute(
            `INSERT INTO Announcement (UserId, PostContent, ClassId, SchoolId) VALUES (?, ?, ?, ?)`,
            [teacherId, 'Selamat datang di Fisika Lanjutan. Mohon periksa tugas pertama kalian.', classId, schoolId]
        );

        // 5. Create Assignments
        const [assignmentResult] = await db.execute(
            `INSERT INTO Assignments (ClassId, Title, Description, DueDate, CreatedById, SchoolId) VALUES (?, ?, ?, ?, ?, ?)`,
            [classId, 'Tugas Teori Relativitas', 'Jelaskan teori relativitas khusus Einstein.', '2027-01-01 23:59:00', teacherId, schoolId]
        );
        const assignmentId = assignmentResult.insertId;

        // 6. Create Submission
        await db.execute(
            `INSERT INTO Submissions (AssignmentId, StudentId, AnswerText, FilePath, Grade, Feedback, SchoolId) VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [assignmentId, studentId, 'Berikut adalah jawaban saya.', '/dummy/jawaban_fisika.pdf', 95, 'Sangat baik!', schoolId]
        );

        // 7. Create Materials
        await db.execute(
            `INSERT INTO Materials (ClassId, Title, FilePath, UploadedById, SchoolId) VALUES (?, ?, ?, ?, ?)`,
            [classId, 'Materi Relativitas PDF', '/dummy/materi_relativitas.pdf', teacherId, schoolId]
        );

        // 8. Schedule
        await db.execute(
            `INSERT INTO Schedule (SchoolId, ClassId, UserId, Title, ScheduleType, DayOfWeek, StartTime, EndTime, Room) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [schoolId, classId, teacherId, 'Kelas Tatap Muka Fisika', 'regular', 'Senin', '08:00:00', '10:00:00', 'Lab Fisika']
        );

        // 9. EkskulSchedule
        await db.execute(
            `INSERT INTO EkskulSchedule (SchoolId, EkskulName, Description, CoachUserId, DayOfWeek, StartTime, EndTime, Room) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [schoolId, 'Klub Sains', 'Ekskul mendalami sains', teacherId, 'Sabtu', '09:00:00', '12:00:00', 'Lab Terpadu']
        );

        // 10. EventSchedule
        await db.execute(
            `INSERT INTO EventSchedule (SchoolId, Title, Description, EventDate, StartTime, EndTime, Room, DressCode, CreatedByUserId) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [schoolId, 'Pekan Raya Sains', 'Pameran karya siswa', '2027-02-10', '08:00:00', '15:00:00', 'Aula Sekolah', 'Bebas Rapi', teacherId]
        );

        // 11. ExamGrid
        await db.execute(
            `INSERT INTO ExamGrid (SchoolId, ClassId, CreatedByUserId, Title, Subject, ExamDate, StartTime, EndTime, Room, RequiredApps, Rules, ExamType) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [schoolId, classId, teacherId, 'Ujian Akhir Semester Fisika', 'Fisika', '2027-03-01', '08:00:00', '10:00:00', 'Ruang 202', 'Tidak ada', 'Dilarang membawa catatan', 'UAS']
        );

        // 12. News
        const [newsResult] = await db.execute(
            `INSERT INTO News (SchoolId, UserId, Title, Content) VALUES (?, ?, ?, ?)`,
            [schoolId, teacherId, 'Pendaftaran Klub Sains Dibuka', 'Segera daftarkan diri Anda di Klub Sains tahun ini!']
        );
        const newsId = newsResult.insertId;

        // 13. NewsMedia
        await db.execute(
            `INSERT INTO NewsMedia (NewsId, MediaType, FileName, FilePath) VALUES (?, ?, ?, ?)`,
            [newsId, 'image', 'poster_sains.jpg', '/dummy/poster_sains.jpg']
        );

        console.log('✅ Dummy data successfully generated logically linking User -> Classes -> Assignments etc.');
    } catch (error) {
        console.error('❌ Error seeding dummy data:', error);
    } finally {
        process.exit();
    }
}

seedDummyData();
