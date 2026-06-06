const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const db = require('./config/db');

const app = express();
app.use(cors());
app.use(express.json());

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
        const { name, email, password, role } = req.body;
        
        // Check if user exists
        const [existingUsers] = await db.execute('SELECT * FROM users WHERE email = ?', [email]);
        if (existingUsers.length > 0) {
            return res.status(400).json({ message: 'Email already exists' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);
        
        // Insert user
        const [result] = await db.execute(
            'INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)',
            [name, email, hashedPassword, role || 'student']
        );

        res.status(201).json({ message: 'User registered successfully', userId: result.insertId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        
        // Find user
        const [users] = await db.execute('SELECT * FROM users WHERE email = ?', [email]);
        if (users.length === 0) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }
        
        const user = users[0];
        
        // Check password
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }
        
        // Generate JWT
        const token = jwt.sign(
            { id: user.id, email: user.email, role: user.role, name: user.name },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        res.json({
            message: 'Login successful',
            token,
            user: { id: user.id, name: user.name, email: user.email, role: user.role }
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
        
        const [result] = await db.execute(
            'INSERT INTO classes (name, description, section, room, subject, class_code, teacher_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [name, description || null, section || null, room || null, subject || null, classCode, req.user.id]
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
        const [classes] = await db.execute('SELECT id FROM classes WHERE class_code = ?', [classCode]);
        if (classes.length === 0) {
            return res.status(404).json({ message: 'Class not found' });
        }
        
        const classId = classes[0].id;
        
        // Check if already enrolled
        const [enrollments] = await db.execute(
            'SELECT * FROM class_enrollments WHERE class_id = ? AND student_id = ?',
            [classId, req.user.id]
        );
        
        if (enrollments.length > 0) {
            return res.status(400).json({ message: 'Already enrolled in this class' });
        }
        
        // Enroll
        await db.execute(
            'INSERT INTO class_enrollments (class_id, student_id) VALUES (?, ?)',
            [classId, req.user.id]
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
            query = 'SELECT * FROM classes WHERE teacher_id = ? ORDER BY created_at DESC';
        } else {
            query = `
                SELECT c.* 
                FROM classes c 
                JOIN class_enrollments ce ON c.id = ce.class_id 
                WHERE ce.student_id = ? 
                ORDER BY c.created_at DESC
            `;
        }
        
        const [classes] = await db.execute(query, params);
        res.json(classes);
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
        console.log('✅ Database connected successfully');
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
