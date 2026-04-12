-- =============================================================
-- V2: Add user accounts and device ownership to central database
-- =============================================================
-- Adds User vertex type for authentication and OwnsDevice edge
-- type linking users to their vehicles for fleet management.

-- -------------------------------------------------------------
-- Vertex: User
-- Represents an authenticated user account.
-- -------------------------------------------------------------
CREATE VERTEX TYPE User IF NOT EXISTS;
CREATE PROPERTY User.email IF NOT EXISTS STRING;
CREATE PROPERTY User.display_name IF NOT EXISTS STRING;
CREATE PROPERTY User.password_hash IF NOT EXISTS STRING;
CREATE PROPERTY User.created_at IF NOT EXISTS DATETIME;
CREATE PROPERTY User.last_login_at IF NOT EXISTS DATETIME;
CREATE PROPERTY User.active IF NOT EXISTS BOOLEAN;

CREATE INDEX IF NOT EXISTS ON User (email) UNIQUE;

-- -------------------------------------------------------------
-- Edge: OwnsDevice
-- Links a User to the Vehicles they own or operate.
-- -------------------------------------------------------------
CREATE EDGE TYPE OwnsDevice IF NOT EXISTS;
CREATE PROPERTY OwnsDevice.registered_at IF NOT EXISTS DATETIME;
CREATE PROPERTY OwnsDevice.role IF NOT EXISTS STRING;
