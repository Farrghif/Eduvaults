const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const db = require('./config/db');

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadsDir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ 
    storage,
    limits: { fileSize: 10 * 1024 * 1024 } // 10MB max
});

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Serve uploaded files
app.use('/api/uploads', express.static(uploadsDir));

// Get list of majors
app.get('/api/majors', async (req, res) => {
    try {
        const [majors] = await db.execute('SELECT Id, Name FROM Major ORDER BY Name ASC');
        res.json(majors);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Middleware to authenticate token
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (token == null) return res.sendStatus(401);

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
};

// ======================= AUTH ROUTES =======================

app.post('/api/auth/register', async (req, res) => {
    try {
        const { name, email, password, role, genderId, religionId, bloodType, birthDate, address, phoneNumber, username, nis, nisn, majorId } = req.body;

        // Check if user exists
        const [existingUsers] = await db.execute('SELECT * FROM User WHERE Email = ?', [email]);
        if (existingUsers.length > 0) {
            const existingUser = existingUsers[0];
            if (existingUser.IsActive == 0 || existingUser.IsActive === false) {
                // If the user hasn't verified yet, we delete their unverified record 
                // so they can register again and get a new OTP.
                await db.execute('DELETE FROM SchoolMember WHERE UserId = ?', [existingUser.Id]);
                await db.execute('DELETE FROM User WHERE Id = ?', [existingUser.Id]);
            } else {
                return res.status(400).json({ message: 'Email already exists' });
            }
        }

        // Get RoleId
        const [roles] = await db.execute('SELECT Id FROM Role WHERE Name = ?', [role || 'student']);
        let roleId;
        if (roles.length > 0) {
            roleId = roles[0].Id;
        } else {
            const [newRole] = await db.execute('INSERT INTO Role (Name) VALUES (?)', [role || 'student']);
            roleId = newRole.insertId;
        }

        // --- SEED ESSENTIAL LOOKUP DATA IF MISSING ---
        const [schools] = await db.execute('SELECT Id FROM School WHERE Id = 1');
        if (schools.length === 0) {
            await db.execute("INSERT INTO School (Id, SchoolName, SchoolCode, Address) VALUES (1, 'Default School', 'SCH001', 'Jl. Pendidikan No 1')");
        }
        const [genders] = await db.execute('SELECT Id FROM Gender WHERE Id = 1');
        if (genders.length === 0) {
            await db.execute("INSERT INTO Gender (Id, Name) VALUES (1, 'Laki-laki'), (2, 'Perempuan')");
        }
        const [religions] = await db.execute('SELECT Id FROM Religion WHERE Id = 1');
        if (religions.length === 0) {
            await db.execute("INSERT INTO Religion (Id, Name) VALUES (1, 'Islam'), (2, 'Kristen'), (3, 'Katolik'), (4, 'Hindu'), (5, 'Buddha'), (6, 'Konghucu')");
        }
        // ---------------------------------------------

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);
        
        // Generate OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiresAt = new Date(Date.now() + 15 * 60000); // 15 mins
        
        // Insert user
        const insertQuery = `
            INSERT INTO User (
                Username, Fullname, Email, Password, RoleId, 
                GenderId, ReligionId, BloodType, NIS, NISN, MajorId, BirthDate, Address, PhoneNumber, IsActive, OtpCode, OtpExpiresAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
        `;

        const [result] = await db.execute(insertQuery, [
            username || email.split('@')[0], 
            name, 
            email, 
            hashedPassword, 
            roleId,
            genderId || 1,
            religionId || 1,
            bloodType || '-',
            nis || null,
            nisn || null,
            majorId || null,
            birthDate || '2000-01-01',
            address || '-',
            phoneNumber || '-',
            otpCode,
            otpExpiresAt
        ]);

        const userId = result.insertId;

        // Add user to SchoolMember (Default SchoolId = 1)
        await db.execute(
            'INSERT INTO SchoolMember (SchoolId, UserId, MemberRoleId, NIS, NISN, MajorId, JoinedAt) VALUES (?, ?, ?, ?, ?, ?, NOW())',
            [1, userId, roleId, nis || null, nisn || null, majorId || null]
        );

        // Send Email
        let transporter;
        let isUsingEthereal = false;
        
        if (process.env.GMAIL_USER && process.env.GMAIL_PASS && process.env.GMAIL_USER !== 'your_gmail@gmail.com') {
            transporter = nodemailer.createTransport({
                service: 'gmail',
                auth: {
                    user: process.env.GMAIL_USER,
                    pass: process.env.GMAIL_PASS
                }
            });
        } else {
            console.log('Using Ethereal Email for testing (No real Gmail credentials provided)...');
            isUsingEthereal = true;
            const testAccount = await nodemailer.createTestAccount();
            transporter = nodemailer.createTransport({
                host: "smtp.ethereal.email",
                port: 587,
                secure: false,
                auth: {
                    user: testAccount.user,
                    pass: testAccount.pass,
                },
            });
        }

        const mailOptions = {
            from: '"EduVaults Auth" <no-reply@eduvaults.com>',
            to: email,
            subject: 'EduVaults - Email Verification OTP',
            text: `Your OTP for EduVaults verification is: ${otpCode}. It expires in 15 minutes.`
        };

        try {
            const info = await transporter.sendMail(mailOptions);
            if (isUsingEthereal) {
                console.log("Test Email sent. Preview URL: %s", nodemailer.getTestMessageUrl(info));
                return res.status(201).json({ 
                    message: 'User registered. Using Dev mode: OTP is ' + otpCode, 
                    userId, 
                    devOtp: otpCode 
                });
            }
        } catch (mailError) {
            console.error('Failed to send OTP email:', mailError);
        }

        res.status(201).json({ message: 'User registered successfully. Please check your email for the OTP.', userId });
    } catch (error) {
        console.error('Registration Error:', error);
        res.status(500).json({ message: error.message || 'Server error' });
    }
});

app.post('/api/auth/verify-email', async (req, res) => {
    try {
        const { email, otp } = req.body;
        const [users] = await db.execute('SELECT Id, OtpCode, OtpExpiresAt FROM User WHERE Email = ?', [email]);
        
        if (users.length === 0) return res.status(400).json({ message: 'User not found' });
        
        const user = users[0];
        
        if (user.OtpCode !== otp) {
            return res.status(400).json({ message: 'Invalid OTP' });
        }
        
        if (new Date() > new Date(user.OtpExpiresAt)) {
            return res.status(400).json({ message: 'OTP has expired' });
        }
        
        await db.execute('UPDATE User SET IsActive = 1, OtpCode = NULL, OtpExpiresAt = NULL WHERE Id = ?', [user.Id]);
        
        res.json({ message: 'Email verified successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        // Find user
        const query = `
            SELECT u.*, r.Name as RoleName 
            FROM User u 
            LEFT JOIN Role r ON u.RoleId = r.Id 
            WHERE u.Email = ?
        `;
        const [users] = await db.execute(query, [email]);

        if (users.length === 0) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }
        
        const user = users[0];
        
        if (user.IsActive === 0) {
            return res.status(400).json({ message: 'Email not verified. Please verify your email first.', requiresOtp: true });
        }
        
        // Check password
        const isMatch = await bcrypt.compare(password, user.Password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }
        
        // Generate JWT
        const token = jwt.sign(
            { id: user.Id, email: user.Email, role: user.RoleName, name: user.Fullname },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        res.json({
            message: 'Login successful',
            token,
            user: { id: user.Id, name: user.Fullname, email: user.Email, role: user.RoleName }
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= CLASS ROUTES =======================

// Create a class (Teacher only)
app.post('/api/classes', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can create classes' });
    }
    
    try {
        const { name, description, section, room, subject } = req.body;
        const classCode = Math.random().toString(36).substring(2, 8).toUpperCase();
        
        const className = name + ' - ' + classCode;
        const [result] = await db.execute(
            'INSERT INTO Classes (ClassName, Description, TeacherId, SchoolId) VALUES (?, ?, ?, ?)',
            [className, description || '', req.user.id, 1] // Assuming SchoolId = 1
        );
        
        res.status(201).json({ message: 'Class created', classId: result.insertId, classCode });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Join a class (Student only)
app.post('/api/classes/join', authenticateToken, async (req, res) => {
    if (req.user.role !== 'student') {
        return res.status(403).json({ message: 'Only students can join classes this way' });
    }
    
    try {
        const { classCode } = req.body;
        
        // Find class
        const [classes] = await db.execute('SELECT Id, SchoolId FROM Classes WHERE ClassName LIKE ?', [`%${classCode}`]);
        if (classes.length === 0) {
            return res.status(404).json({ message: 'Class not found' });
        }
        
        const classId = classes[0].Id;
        const schoolId = classes[0].SchoolId;
        
        // Check if already enrolled
        const [enrollments] = await db.execute(
            'SELECT * FROM ClassMember WHERE ClassId = ? AND UserId = ?',
            [classId, req.user.id]
        );
        
        if (enrollments.length > 0) {
            return res.status(400).json({ message: 'Already enrolled in this class' });
        }
        
        // Get student role id
        const [roles] = await db.execute('SELECT Id FROM Role WHERE Name = ?', ['student']);
        const memberRoleId = roles.length > 0 ? roles[0].Id : 1;

        // Enroll
        await db.execute(
            'INSERT INTO ClassMember (ClassId, UserId, MemberRoleId, SchoolId) VALUES (?, ?, ?, ?)',
            [classId, req.user.id, memberRoleId, schoolId]
        );
        
        res.json({ message: 'Successfully joined class' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get user's classes
app.get('/api/classes', authenticateToken, async (req, res) => {
    try {
        let query;
        let params = [req.user.id];
        
        if (req.user.role === 'teacher') {
            query = 'SELECT *, Id as id, ClassName as name, Description as description FROM Classes WHERE TeacherId = ? ORDER BY CreatedAt DESC';
        } else {
            query = `
                SELECT c.*, c.Id as id, c.ClassName as name, c.Description as description 
                FROM Classes c 
                JOIN ClassMember ce ON c.Id = ce.ClassId 
                WHERE ce.UserId = ? 
                ORDER BY c.CreatedAt DESC
            `;
        }
        
        const [classes] = await db.execute(query, params);
        
        // Extract class_code from ClassName
        const mappedClasses = classes.map(c => {
            const parts = c.name.split(' - ');
            const classCode = parts.length > 1 ? parts[parts.length - 1] : '';
            return {
                ...c,
                class_code: classCode
            };
        });
        
        res.json(mappedClasses);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Edit a class
app.put('/api/classes/:classId', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') return res.status(403).json({ message: 'Only teachers can edit classes' });
    try {
        const { classId } = req.params;
        const { name, description } = req.body;
        
        const [classes] = await db.execute('SELECT Id FROM Classes WHERE Id = ? AND TeacherId = ?', [classId, req.user.id]);
        if (classes.length === 0) return res.status(403).json({ message: 'Not authorized' });

        await db.execute('UPDATE Classes SET ClassName = ?, Description = ? WHERE Id = ?', [name, description || '', classId]);
        res.json({ message: 'Class updated' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete a class
app.delete('/api/classes/:classId', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') return res.status(403).json({ message: 'Only teachers can delete classes' });
    try {
        const { classId } = req.params;
        const [classes] = await db.execute('SELECT Id FROM Classes WHERE Id = ? AND TeacherId = ?', [classId, req.user.id]);
        if (classes.length === 0) return res.status(403).json({ message: 'Not authorized' });

        // Delete dependencies first
        await db.execute('DELETE FROM Submissions WHERE AssignmentId IN (SELECT Id FROM Assignments WHERE ClassId = ?)', [classId]);
        await db.execute('DELETE FROM Assignments WHERE ClassId = ?', [classId]);
        await db.execute('DELETE FROM Announcement WHERE ClassId = ?', [classId]);
        await db.execute('DELETE FROM Materials WHERE ClassId = ?', [classId]);
        await db.execute('DELETE FROM ClassMember WHERE ClassId = ?', [classId]);
        await db.execute('DELETE FROM ExamGrid WHERE ClassId = ?', [classId]);
        await db.execute('DELETE FROM Schedule WHERE ClassId = ?', [classId]);
        
        // Delete Questions dependencies
        await db.execute('DELETE FROM QuestionSubmissions WHERE QuestionId IN (SELECT Id FROM Questions WHERE ClassId = ?)', [classId]);
        await db.execute('DELETE FROM Questions WHERE ClassId = ?', [classId]);

        
        // Delete class
        await db.execute('DELETE FROM Classes WHERE Id = ?', [classId]);
        res.json({ message: 'Class deleted' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Leave a class
app.delete('/api/classes/:classId/leave', authenticateToken, async (req, res) => {
    if (req.user.role !== 'student') return res.status(403).json({ message: 'Only students can leave classes' });
    try {
        const { classId } = req.params;
        await db.execute('DELETE FROM ClassMember WHERE ClassId = ? AND UserId = ?', [classId, req.user.id]);
        res.json({ message: 'Left class successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= STREAM / ANNOUNCEMENTS =======================

app.get('/api/classes/:classId/announcements', authenticateToken, async (req, res) => {
    try {
        const { classId } = req.params;
        const query = `
            SELECT a.*, u.Fullname as authorName 
            FROM Announcement a
            JOIN User u ON a.UserId = u.Id
            WHERE a.ClassId = ?
            ORDER BY a.CreatedAt DESC
        `;
        const [announcements] = await db.execute(query, [classId]);
        res.json(announcements);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

app.post('/api/classes/:classId/announcements', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can post announcements' });
    }
    try {
        const { classId } = req.params;
        const { content } = req.body;
        
        if (!content) return res.status(400).json({ message: 'Content is required' });

        const [result] = await db.execute(
            'INSERT INTO Announcement (UserId, PostContent, ClassId, SchoolId) VALUES (?, ?, ?, 1)',
            [req.user.id, content, classId]
        );
        
        res.status(201).json({ message: 'Announcement created', id: result.insertId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete announcement
app.delete('/api/announcements/:id', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can delete announcements' });
    }
    try {
        const [items] = await db.execute('SELECT UserId FROM Announcement WHERE Id = ?', [req.params.id]);
        if (items.length === 0) return res.status(404).json({ message: 'Not found' });
        
        await db.execute('DELETE FROM Announcement WHERE Id = ?', [req.params.id]);
        res.json({ message: 'Deleted' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= CLASSWORK / ASSIGNMENTS =======================

// Get all assignments for a class (with submission status for students)
app.get('/api/classes/:classId/assignments', authenticateToken, async (req, res) => {
    try {
        const { classId } = req.params;
        const query = `
            SELECT a.*, u.Fullname as creatorName 
            FROM Assignments a
            JOIN User u ON a.CreatedById = u.Id
            WHERE a.ClassId = ?
            ORDER BY a.DueDate ASC
        `;
        const [assignments] = await db.execute(query, [classId]);

        // If user is a student, add submission status for each assignment
        if (req.user.role === 'student') {
            for (let i = 0; i < assignments.length; i++) {
                const [subs] = await db.execute(
                    'SELECT Id, Grade, SubmittedAt FROM Submissions WHERE AssignmentId = ? AND StudentId = ?',
                    [assignments[i].Id, req.user.id]
                );
                if (subs.length > 0) {
                    assignments[i].submissionStatus = subs[0].Grade != null ? 'graded' : 'submitted';
                    assignments[i].submissionGrade = subs[0].Grade;
                    assignments[i].submittedAt = subs[0].SubmittedAt;
                } else {
                    assignments[i].submissionStatus = 'not_submitted';
                }
            }
        }

        // If user is a teacher, add submission count
        if (req.user.role === 'teacher') {
            for (let i = 0; i < assignments.length; i++) {
                const [countResult] = await db.execute(
                    'SELECT COUNT(*) as count FROM Submissions WHERE AssignmentId = ?',
                    [assignments[i].Id]
                );
                assignments[i].submissionCount = countResult[0].count;
            }
        }

        res.json(assignments);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Create a new assignment (teacher only)
app.post('/api/classes/:classId/assignments', authenticateToken, upload.single('file'), async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can create assignments' });
    }
    try {
        const { classId } = req.params;
        const { title, description, dueDate } = req.body;
        const filePath = req.file ? req.file.filename : null;
        
        if (!title || !dueDate) return res.status(400).json({ message: 'Title and due date are required' });

        const [result] = await db.execute(
            'INSERT INTO Assignments (ClassId, Title, Description, FilePath, DueDate, CreatedById, SchoolId) VALUES (?, ?, ?, ?, ?, ?, 1)',
            [classId, title, description || '', filePath, dueDate, req.user.id]
        );
        
        res.status(201).json({ message: 'Assignment created', id: result.insertId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get single assignment detail
app.get('/api/assignments/:assignmentId', authenticateToken, async (req, res) => {
    try {
        const { assignmentId } = req.params;
        const query = `
            SELECT a.*, u.Fullname as creatorName, c.ClassName 
            FROM Assignments a
            JOIN User u ON a.CreatedById = u.Id
            JOIN Classes c ON a.ClassId = c.Id
            WHERE a.Id = ?
        `;
        const [assignments] = await db.execute(query, [assignmentId]);
        if (assignments.length === 0) {
            return res.status(404).json({ message: 'Assignment not found' });
        }
        res.json(assignments[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete assignment
app.delete('/api/assignments/:id', authenticateToken, async (req, res) => {
    try {
        const [items] = await db.execute('SELECT CreatedById FROM Assignments WHERE Id = ?', [req.params.id]);
        if (items.length === 0) return res.status(404).json({ message: 'Not found' });
        if (items[0].CreatedById !== req.user.id) return res.status(403).json({ message: 'Not authorized' });
        
        await db.execute('DELETE FROM Submissions WHERE AssignmentId = ?', [req.params.id]);
        await db.execute('DELETE FROM Assignments WHERE Id = ?', [req.params.id]);
        res.json({ message: 'Deleted' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= MATERIALS =======================

// Get all materials for a class
app.get('/api/classes/:classId/materials', authenticateToken, async (req, res) => {
    try {
        const { classId } = req.params;
        const query = `
            SELECT m.*, u.Fullname as uploaderName 
            FROM Materials m
            JOIN User u ON m.UploadedById = u.Id
            WHERE m.ClassId = ?
            ORDER BY m.CreatedAt DESC
        `;
        const [materials] = await db.execute(query, [classId]);
        res.json(materials);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Create a new material (teacher only)
app.post('/api/classes/:classId/materials', authenticateToken, upload.single('file'), async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can create materials' });
    }
    try {
        const { classId } = req.params;
        const { title } = req.body;
        const filePath = req.file ? req.file.filename : '';
        
        if (!title) return res.status(400).json({ message: 'Title is required' });

        const [result] = await db.execute(
            'INSERT INTO Materials (ClassId, Title, FilePath, UploadedById, SchoolId) VALUES (?, ?, ?, ?, 1)',
            [classId, title, filePath, req.user.id]
        );
        
        res.status(201).json({ message: 'Material created', id: result.insertId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete material
app.delete('/api/materials/:id', authenticateToken, async (req, res) => {
    try {
        const [items] = await db.execute('SELECT UploadedById FROM Materials WHERE Id = ?', [req.params.id]);
        if (items.length === 0) return res.status(404).json({ message: 'Not found' });
        if (items[0].UploadedById !== req.user.id) return res.status(403).json({ message: 'Not authorized' });
        
        await db.execute('DELETE FROM Materials WHERE Id = ?', [req.params.id]);
        res.json({ message: 'Deleted' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= QUESTIONS =======================

// Get all questions for a class
app.get('/api/classes/:classId/questions', authenticateToken, async (req, res) => {
    try {
        const { classId } = req.params;
        const query = `
            SELECT q.*, u.Fullname as creatorName 
            FROM Questions q
            JOIN User u ON q.CreatedById = u.Id
            WHERE q.ClassId = ?
            ORDER BY q.CreatedAt DESC
        `;
        const [questions] = await db.execute(query, [classId]);

        for (let i = 0; i < questions.length; i++) {
            if (questions[i].Options) {
                try {
                    questions[i].Options = JSON.parse(questions[i].Options);
                } catch (e) { }
            }
        }
        res.json(questions);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Create a new question
app.post('/api/classes/:classId/questions', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can create questions' });
    }
    try {
        const { classId } = req.params;
        const { title, description, dueDate, type, options } = req.body;

        if (!title || !dueDate) return res.status(400).json({ message: 'Title and due date are required' });

        const [result] = await db.execute(
            'INSERT INTO Questions (ClassId, Title, Description, Type, Options, DueDate, CreatedById, SchoolId) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
            [classId, title, description || '', type || 'short_answer', options ? JSON.stringify(options) : null, dueDate, req.user.id]
        );
        res.status(201).json({ message: 'Question created', id: result.insertId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete a question
app.delete('/api/questions/:id', authenticateToken, async (req, res) => {
    try {
        const [items] = await db.execute('SELECT CreatedById FROM Questions WHERE Id = ?', [req.params.id]);
        if (items.length === 0) return res.status(404).json({ message: 'Not found' });
        if (items[0].CreatedById !== req.user.id) return res.status(403).json({ message: 'Not authorized' });

        await db.execute('DELETE FROM QuestionSubmissions WHERE QuestionId = ?', [req.params.id]);
        await db.execute('DELETE FROM Questions WHERE Id = ?', [req.params.id]);
        res.json({ message: 'Deleted' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get student's submission for a question
app.get('/api/questions/:questionId/submissions/my', authenticateToken, async (req, res) => {
    try {
        const { questionId } = req.params;
        const [submissions] = await db.execute(
            'SELECT * FROM QuestionSubmissions WHERE QuestionId = ? AND StudentId = ?',
            [questionId, req.user.id]
        );
        if (submissions.length === 0) {
            return res.json(null);
        }
        res.json(submissions[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get all submissions for a question (teacher view)
app.get('/api/questions/:questionId/submissions', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') return res.status(403).json({ message: 'Not authorized' });
    try {
        const { questionId } = req.params;
        const query = `
            SELECT s.*, u.Fullname as studentName, u.Email as studentEmail
            FROM QuestionSubmissions s
            JOIN User u ON s.StudentId = u.Id
            WHERE s.QuestionId = ?
            ORDER BY s.SubmittedAt DESC
        `;
        const [submissions] = await db.execute(query, [questionId]);
        res.json(submissions);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Student submits an answer for a question
app.post('/api/questions/:questionId/submissions', authenticateToken, async (req, res) => {
    if (req.user.role !== 'student') return res.status(403).json({ message: 'Only students can answer' });
    try {
        const { questionId } = req.params;
        const { answerText } = req.body;

        if (!answerText) return res.status(400).json({ message: 'Please provide an answer' });

        const [questions] = await db.execute('SELECT Id, SchoolId FROM Questions WHERE Id = ?', [questionId]);
        if (questions.length === 0) return res.status(404).json({ message: 'Question not found' });

        const [existing] = await db.execute(
            'SELECT Id FROM QuestionSubmissions WHERE QuestionId = ? AND StudentId = ?',
            [questionId, req.user.id]
        );

        if (existing.length > 0) {
            await db.execute(
                'UPDATE QuestionSubmissions SET AnswerText = ?, SubmittedAt = NOW() WHERE Id = ?',
                [answerText, existing[0].Id]
            );
            return res.json({ message: 'Answer updated', id: existing[0].Id });
        }

        const [result] = await db.execute(
            'INSERT INTO QuestionSubmissions (QuestionId, StudentId, AnswerText, SchoolId) VALUES (?, ?, ?, ?)',
            [questionId, req.user.id, answerText, questions[0].SchoolId]
        );
        res.status(201).json({ message: 'Answer submitted', id: result.insertId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= SUBMISSIONS =======================

// Student submits an assignment (text + optional file)
app.post('/api/assignments/:assignmentId/submissions', authenticateToken, upload.single('file'), async (req, res) => {
    if (req.user.role !== 'student') {
        return res.status(403).json({ message: 'Only students can submit assignments' });
    }
    try {
        const { assignmentId } = req.params;
        const { answerText } = req.body;
        const filePath = req.file ? req.file.filename : '';

        if (!answerText && !req.file) {
            return res.status(400).json({ message: 'Please provide answer text or upload a file' });
        }

        // Check if assignment exists
        const [assignments] = await db.execute('SELECT Id, SchoolId FROM Assignments WHERE Id = ?', [assignmentId]);
        if (assignments.length === 0) {
            return res.status(404).json({ message: 'Assignment not found' });
        }

        // Check if already submitted
        const [existing] = await db.execute(
            'SELECT Id FROM Submissions WHERE AssignmentId = ? AND StudentId = ?',
            [assignmentId, req.user.id]
        );

        if (existing.length > 0) {
            // Update existing submission
            await db.execute(
                'UPDATE Submissions SET AnswerText = ?, FilePath = ?, SubmittedAt = NOW() WHERE Id = ?',
                [answerText || '', filePath, existing[0].Id]
            );
            return res.json({ message: 'Submission updated', id: existing[0].Id });
        }

        // Create new submission
        const [result] = await db.execute(
            'INSERT INTO Submissions (AssignmentId, StudentId, AnswerText, FilePath, SchoolId, Feedback) VALUES (?, ?, ?, ?, ?, ?)',
            [assignmentId, req.user.id, answerText || '', filePath, assignments[0].SchoolId, '']
        );
        
        res.status(201).json({ message: 'Submission created', id: result.insertId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get all submissions for an assignment (teacher view)
app.get('/api/assignments/:assignmentId/submissions', authenticateToken, async (req, res) => {
    try {
        const { assignmentId } = req.params;
        const query = `
            SELECT s.*, u.Fullname as studentName, u.Email as studentEmail
            FROM Submissions s
            JOIN User u ON s.StudentId = u.Id
            WHERE s.AssignmentId = ?
            ORDER BY s.SubmittedAt DESC
        `;
        const [submissions] = await db.execute(query, [assignmentId]);
        res.json(submissions);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get student's own submission for an assignment
app.get('/api/assignments/:assignmentId/submissions/my', authenticateToken, async (req, res) => {
    try {
        const { assignmentId } = req.params;
        const [submissions] = await db.execute(
            'SELECT * FROM Submissions WHERE AssignmentId = ? AND StudentId = ?',
            [assignmentId, req.user.id]
        );
        if (submissions.length === 0) {
            return res.json(null);
        }
        res.json(submissions[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= GRADING =======================

// Teacher grades a submission
app.put('/api/submissions/:submissionId/grade', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can grade submissions' });
    }
    try {
        const { submissionId } = req.params;
        const { grade, feedback } = req.body;

        if (grade == null || grade < 0 || grade > 100) {
            return res.status(400).json({ message: 'Grade must be between 0 and 100' });
        }

        const [result] = await db.execute(
            'UPDATE Submissions SET Grade = ?, Feedback = ? WHERE Id = ?',
            [grade, feedback || '', submissionId]
        );

        if (result.affectedRows === 0) {
            // Try QuestionSubmissions
            const [qResult] = await db.execute(
                'UPDATE QuestionSubmissions SET Grade = ?, Feedback = ? WHERE Id = ?',
                [grade, feedback || '', submissionId]
            );
            if (qResult.affectedRows === 0) {
                return res.status(404).json({ message: 'Submission not found' });
            }
        }

        res.json({ message: 'Grade saved successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= TODO / TO REVIEW =======================

app.get('/api/users/todo', authenticateToken, async (req, res) => {
    try {
        if (req.user.role === 'teacher') {
            // Teacher: To Review (Assignments with un-graded submissions)
            const query = `
                SELECT a.*, c.ClassName,
                (SELECT COUNT(*) FROM Submissions s WHERE s.AssignmentId = a.Id) as submissionCount,
                (SELECT COUNT(*) FROM Submissions s WHERE s.AssignmentId = a.Id AND s.Grade IS NULL) as needsReviewCount
                FROM Assignments a
                JOIN Classes c ON a.ClassId = c.Id
                WHERE a.CreatedById = ?
                ORDER BY a.DueDate ASC
            `;
            const [assignments] = await db.execute(query, [req.user.id]);
            res.json(assignments);
        } else {
            // Student: To-Do (Assigned, Missing, Done)
            const query = `
                SELECT a.*, c.ClassName, s.Grade, s.SubmittedAt, s.Id as submissionId
                FROM Assignments a
                JOIN ClassMember cm ON a.ClassId = cm.ClassId
                JOIN Classes c ON a.ClassId = c.Id
                LEFT JOIN Submissions s ON a.Id = s.AssignmentId AND s.StudentId = ?
                WHERE cm.UserId = ?
                ORDER BY a.DueDate ASC
            `;
            const [assignments] = await db.execute(query, [req.user.id, req.user.id]);
            
            // Map status
            const mapped = assignments.map(a => {
                const dueDate = new Date(a.DueDate);
                const isOverdue = dueDate < new Date();
                let status;
                if (a.Grade != null) status = 'graded';
                else if (a.submissionId != null) status = 'submitted';
                else if (isOverdue) status = 'missing';
                else status = 'assigned';

                return { ...a, submissionStatus: status };
            });

            res.json(mapped);
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= PROFILE =======================

app.get('/api/users/profile', authenticateToken, async (req, res) => {
    try {
        const [users] = await db.execute('SELECT Id, Username, Fullname, Email, PhoneNumber, Address, BirthDate, BloodType, NIS, NISN FROM User WHERE Id = ?', [req.user.id]);
        if (users.length === 0) return res.status(404).json({ message: 'User not found' });
        res.json(users[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

app.put('/api/users/profile', authenticateToken, async (req, res) => {
    try {
        const { Fullname, PhoneNumber, Address, BloodType } = req.body;
        await db.execute(
            'UPDATE User SET Fullname = ?, PhoneNumber = ?, Address = ?, BloodType = ? WHERE Id = ?',
            [Fullname || '', PhoneNumber || '', Address || '', BloodType || '', req.user.id]
        );
        res.json({ message: 'Profile updated successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= PEOPLE / MEMBERS =======================

app.get('/api/classes/:classId/members', authenticateToken, async (req, res) => {
    try {
        const { classId } = req.params;
        
        // Get Teacher
        const teacherQuery = `
            SELECT u.Id, u.Fullname, u.Email, u.ProfileImage, 'teacher' as RoleName
            FROM Classes c
            JOIN User u ON c.TeacherId = u.Id
            WHERE c.Id = ?
        `;
        const [teachers] = await db.execute(teacherQuery, [classId]);
        
        // Get Students
        const studentQuery = `
            SELECT u.Id, u.Fullname, u.Email, u.ProfileImage, r.Name as RoleName, u.NIS, u.NISN, u.MajorId, m.Name as MajorName
            FROM ClassMember cm
            JOIN User u ON cm.UserId = u.Id
            JOIN Role r ON cm.MemberRoleId = r.Id
            LEFT JOIN Major m ON u.MajorId = m.Id
            WHERE cm.ClassId = ?
            ORDER BY u.Fullname ASC
        `;
        const [students] = await db.execute(studentQuery, [classId]);
        
        res.json({ teachers, students });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Update student info (teacher only)
app.put('/api/classes/:classId/members/:studentId', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher' && req.user.role !== 'admin') {
        return res.status(403).json({ message: 'Only teachers or admins can update student info' });
    }
    try {
        const { studentId } = req.params;
        const { nis, nisn, majorId } = req.body;

        // Update User table
        await db.execute(
            'UPDATE User SET NIS = ?, NISN = ?, MajorId = ? WHERE Id = ?',
            [nis || null, nisn || null, majorId || null, studentId]
        );

        // Update SchoolMember table
        await db.execute(
            'UPDATE SchoolMember SET NIS = ?, NISN = ?, MajorId = ? WHERE UserId = ?',
            [nis || null, nisn || null, majorId || null, studentId]
        );

        res.json({ message: 'Student info updated successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

app.delete('/api/classes/:classId/members/:studentId', authenticateToken, async (req, res) => {
    if (req.user.role !== 'teacher') {
        return res.status(403).json({ message: 'Only teachers can remove members' });
    }
    try {
        const { classId, studentId } = req.params;
        // Verify teacher owns the class or is part of it
        const [classes] = await db.execute('SELECT Id FROM Classes WHERE Id = ? AND TeacherId = ?', [classId, req.user.id]);
        if (classes.length === 0) {
            return res.status(403).json({ message: 'Not authorized to manage this class' });
        }
        
        const [result] = await db.execute('DELETE FROM ClassMember WHERE ClassId = ? AND UserId = ?', [classId, studentId]);
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Member not found in class' });
        }
        res.json({ message: 'Member removed successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ======================= HEALTH CHECK =======================

app.get('/api/health', async (req, res) => {
    try {
        await db.execute('SELECT 1');
        res.json({ status: 'ok', message: 'Server and database are running' });
    } catch (error) {
        res.status(500).json({ status: 'error', message: 'Database connection failed', error: error.message });
    }
});

const PORT = process.env.PORT || 5000;

// Verify DB connection before starting server
(async () => {
    try {
        await db.execute('SELECT 1');
        
        // Auto-create Questions and QuestionSubmissions tables if not exists
        await db.execute(`
            CREATE TABLE IF NOT EXISTS Questions (
                Id INT AUTO_INCREMENT PRIMARY KEY,
                ClassId INT NOT NULL,
                Title VARCHAR(150) NOT NULL,
                Description VARCHAR(500) NULL,
                Type VARCHAR(50) NOT NULL,
                Options JSON NULL,
                DueDate DATETIME NOT NULL,
                CreatedById INT NOT NULL,
                CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                SchoolId INT NOT NULL,
                FOREIGN KEY (ClassId) REFERENCES Classes(Id),
                FOREIGN KEY (CreatedById) REFERENCES User(Id),
                FOREIGN KEY (SchoolId) REFERENCES School(Id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        `);
        
        await db.execute(`
            CREATE TABLE IF NOT EXISTS QuestionSubmissions (
                Id INT AUTO_INCREMENT PRIMARY KEY,
                QuestionId INT NOT NULL,
                StudentId INT NOT NULL,
                AnswerText VARCHAR(1000) NOT NULL,
                SubmittedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                Grade INT NULL,
                Feedback VARCHAR(500) NULL,
                SchoolId INT NOT NULL,
                FOREIGN KEY (QuestionId) REFERENCES Questions(Id),
                FOREIGN KEY (StudentId) REFERENCES User(Id),
                FOREIGN KEY (SchoolId) REFERENCES School(Id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        `);

        console.log('✅ Database connected and tables verified');
    } catch (error) {
        console.error('❌ Database connection failed:', error.message);
        console.error('   Make sure MySQL is running and the database "eduvaults" exists.');
        process.exit(1);
    }

    // Bind to 0.0.0.0 so emulators and physical devices can connect
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
    });
})();
