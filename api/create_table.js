const db = require('./config/db');

async function createTable() {
    try {
        const sql = `
            CREATE TABLE IF NOT EXISTS StudentAssignment (
                Id INT AUTO_INCREMENT PRIMARY KEY,
                AssignmentId INT NOT NULL,
                StudentId INT NOT NULL,
                Status VARCHAR(50) DEFAULT 'assigned',
                AssignedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (AssignmentId) REFERENCES Assignments(Id),
                FOREIGN KEY (StudentId) REFERENCES User(Id)
            )
        `;
        await db.execute(sql);
        console.log('✅ StudentAssignment table created successfully');
    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        process.exit();
    }
}

createTable();
