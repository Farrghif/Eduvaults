const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigration() {
    console.log('Connecting to database...');
    const db = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
    });

    console.log('Running ALTER TABLE...');
    try {
        await db.execute('ALTER TABLE Assignments ADD COLUMN FilePath VARCHAR(750) NULL AFTER Description');
        console.log('✅ Migration successful: FilePath column added to Assignments.');
    } catch (e) {
        if (e.code === 'ER_DUP_FIELDNAME') {
            console.log('✅ Migration successful: FilePath column already exists in Assignments.');
        } else {
            console.error('❌ Migration failed:', e.message);
        }
    } finally {
        await db.end();
    }
}

runMigration();
