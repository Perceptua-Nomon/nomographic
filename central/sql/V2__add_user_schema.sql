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
ALTER PROPERTY User.email MANDATORY true;
ALTER PROPERTY User.email NOTNULL true;
CREATE PROPERTY User.display_name IF NOT EXISTS STRING;
ALTER PROPERTY User.display_name MANDATORY true;
ALTER PROPERTY User.display_name NOTNULL true;
CREATE PROPERTY User.password_hash IF NOT EXISTS STRING;
ALTER PROPERTY User.password_hash MANDATORY true;
ALTER PROPERTY User.password_hash NOTNULL true;
CREATE PROPERTY User.created_at IF NOT EXISTS DATETIME;
ALTER PROPERTY User.created_at MANDATORY true;
ALTER PROPERTY User.created_at NOTNULL true;
CREATE PROPERTY User.last_login_at IF NOT EXISTS DATETIME;
CREATE PROPERTY User.active IF NOT EXISTS BOOLEAN;
ALTER PROPERTY User.active MANDATORY true;
ALTER PROPERTY User.active NOTNULL true;

CREATE INDEX IF NOT EXISTS ON User (email) UNIQUE;

-- -------------------------------------------------------------
-- Edge: OwnsDevice
-- Links a User to the Vehicles they own or operate.
-- -------------------------------------------------------------
CREATE EDGE TYPE OwnsDevice IF NOT EXISTS;
CREATE PROPERTY OwnsDevice.role IF NOT EXISTS STRING;
ALTER PROPERTY OwnsDevice.role MANDATORY true;
ALTER PROPERTY OwnsDevice.role NOTNULL true;
