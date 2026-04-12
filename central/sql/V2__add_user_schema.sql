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
ALTER TYPE User IF NOT EXISTS CREATE PROPERTY email STRING;
ALTER TYPE User IF NOT EXISTS CREATE PROPERTY display_name STRING;
ALTER TYPE User IF NOT EXISTS CREATE PROPERTY password_hash STRING;
ALTER TYPE User IF NOT EXISTS CREATE PROPERTY created_at DATETIME;
ALTER TYPE User IF NOT EXISTS CREATE PROPERTY last_login_at DATETIME;
ALTER TYPE User IF NOT EXISTS CREATE PROPERTY active BOOLEAN;

CREATE INDEX IF NOT EXISTS ON User (email) UNIQUE;

-- -------------------------------------------------------------
-- Edge: OwnsDevice
-- Links a User to the Vehicles they own or operate.
-- -------------------------------------------------------------
CREATE EDGE TYPE OwnsDevice IF NOT EXISTS;
ALTER TYPE OwnsDevice IF NOT EXISTS CREATE PROPERTY registered_at DATETIME;
ALTER TYPE OwnsDevice IF NOT EXISTS CREATE PROPERTY role STRING;
