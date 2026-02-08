use anyhow::Result;
use rusqlite::Connection;
use serde::Serialize;
use std::sync::Mutex;

#[derive(Clone, Serialize)]
pub struct User {
    pub id: String,
    pub username: String,
    pub display_name: String,
    pub role: String,
    pub created_at: String,
    pub updated_at: String,
}

pub struct UserRow {
    pub id: String,
    pub username: String,
    pub password_hash: String,
    pub display_name: String,
    pub role: String,
    pub created_at: String,
    pub updated_at: String,
}

impl UserRow {
    pub fn to_public(&self) -> User {
        User {
            id: self.id.clone(),
            username: self.username.clone(),
            display_name: self.display_name.clone(),
            role: self.role.clone(),
            created_at: self.created_at.clone(),
            updated_at: self.updated_at.clone(),
        }
    }
}

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn new(path: &str) -> Result<Self> {
        if let Some(parent) = std::path::Path::new(path).parent() {
            std::fs::create_dir_all(parent)?;
        }
        let conn = Connection::open(path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        Ok(Database {
            conn: Mutex::new(conn),
        })
    }

    pub fn initialize(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                display_name TEXT NOT NULL DEFAULT '',
                role TEXT NOT NULL DEFAULT 'user',
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )",
        )?;

        let count: i64 =
            conn.query_row("SELECT COUNT(*) FROM users", [], |row| row.get(0))?;
        if count == 0 {
            let id = uuid::Uuid::new_v4().to_string();
            let password_hash =
                bcrypt::hash("Koder@123", bcrypt::DEFAULT_COST)?;
            conn.execute(
                "INSERT INTO users (id, username, password_hash, display_name, role) VALUES (?1, ?2, ?3, ?4, ?5)",
                (&id, "root", &password_hash, "Administrador", "admin"),
            )?;
            tracing::info!("Created default root user (root / Koder@123)");
        }

        Ok(())
    }

    pub fn get_user_by_username(&self, username: &str) -> Result<Option<UserRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, username, password_hash, display_name, role, created_at, updated_at FROM users WHERE username = ?1",
        )?;
        let mut rows = stmt.query_map([username], |row| {
            Ok(UserRow {
                id: row.get(0)?,
                username: row.get(1)?,
                password_hash: row.get(2)?,
                display_name: row.get(3)?,
                role: row.get(4)?,
                created_at: row.get(5)?,
                updated_at: row.get(6)?,
            })
        })?;
        Ok(rows.next().transpose()?)
    }

    pub fn get_user_by_id(&self, id: &str) -> Result<Option<UserRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, username, password_hash, display_name, role, created_at, updated_at FROM users WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map([id], |row| {
            Ok(UserRow {
                id: row.get(0)?,
                username: row.get(1)?,
                password_hash: row.get(2)?,
                display_name: row.get(3)?,
                role: row.get(4)?,
                created_at: row.get(5)?,
                updated_at: row.get(6)?,
            })
        })?;
        Ok(rows.next().transpose()?)
    }

    pub fn list_users(&self) -> Result<Vec<User>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, username, password_hash, display_name, role, created_at, updated_at FROM users ORDER BY created_at",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(UserRow {
                id: row.get(0)?,
                username: row.get(1)?,
                password_hash: row.get(2)?,
                display_name: row.get(3)?,
                role: row.get(4)?,
                created_at: row.get(5)?,
                updated_at: row.get(6)?,
            })
        })?;
        Ok(rows.filter_map(|r| r.ok()).map(|r| r.to_public()).collect())
    }

    pub fn create_user(
        &self,
        username: &str,
        password: &str,
        display_name: &str,
        role: &str,
    ) -> Result<User> {
        let id = uuid::Uuid::new_v4().to_string();
        let password_hash = bcrypt::hash(password, bcrypt::DEFAULT_COST)?;
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO users (id, username, password_hash, display_name, role) VALUES (?1, ?2, ?3, ?4, ?5)",
            (&id, username, &password_hash, display_name, role),
        )?;
        drop(conn);
        Ok(self.get_user_by_id(&id)?.unwrap().to_public())
    }

    pub fn update_user(
        &self,
        id: &str,
        display_name: Option<&str>,
        role: Option<&str>,
        password: Option<&str>,
    ) -> Result<Option<User>> {
        let conn = self.conn.lock().unwrap();

        if let Some(dn) = display_name {
            conn.execute(
                "UPDATE users SET display_name = ?1, updated_at = datetime('now') WHERE id = ?2",
                (dn, id),
            )?;
        }
        if let Some(r) = role {
            conn.execute(
                "UPDATE users SET role = ?1, updated_at = datetime('now') WHERE id = ?2",
                (r, id),
            )?;
        }
        if let Some(pw) = password {
            let hash = bcrypt::hash(pw, bcrypt::DEFAULT_COST)?;
            conn.execute(
                "UPDATE users SET password_hash = ?1, updated_at = datetime('now') WHERE id = ?2",
                (&hash, id),
            )?;
        }
        drop(conn);
        Ok(self.get_user_by_id(id)?.map(|u| u.to_public()))
    }

    pub fn delete_user(&self, id: &str) -> Result<bool> {
        let conn = self.conn.lock().unwrap();
        let rows = conn.execute("DELETE FROM users WHERE id = ?1", [id])?;
        Ok(rows > 0)
    }

    pub fn update_password(&self, id: &str, new_password: &str) -> Result<()> {
        let hash = bcrypt::hash(new_password, bcrypt::DEFAULT_COST)?;
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE users SET password_hash = ?1, updated_at = datetime('now') WHERE id = ?2",
            (&hash, id),
        )?;
        Ok(())
    }
}
