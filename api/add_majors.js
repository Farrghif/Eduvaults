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

    console.log('Inserting new majors...');
    try {
        await db.execute("INSERT IGNORE INTO Major (Name) VALUES ('RPL'), ('MLOG'), ('DKV'), ('Akuntansi')");
        console.log('✅ New majors added successfully.');
    } catch (e) {
        console.error('❌ Failed to add majors:', e.message);
    } finally {
        await db.end();
    }
}

runMigration();
