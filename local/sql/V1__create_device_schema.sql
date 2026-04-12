-- =============================================================
-- V1: Create core device schema for the nomon local database
-- =============================================================
-- Establishes the foundational vertex types for on-device state
-- management. This schema runs in an embedded ArcadeDB instance
-- on each nomon robot.

-- -------------------------------------------------------------
-- Vertex: DeviceState
-- Singleton-like record holding current operational state.
-- -------------------------------------------------------------
CREATE VERTEX TYPE DeviceState IF NOT EXISTS;
ALTER TYPE DeviceState IF NOT EXISTS CREATE PROPERTY device_id STRING;
ALTER TYPE DeviceState IF NOT EXISTS CREATE PROPERTY firmware_version STRING;
ALTER TYPE DeviceState IF NOT EXISTS CREATE PROPERTY boot_count LONG;
ALTER TYPE DeviceState IF NOT EXISTS CREATE PROPERTY last_boot_at DATETIME;
ALTER TYPE DeviceState IF NOT EXISTS CREATE PROPERTY status STRING;

CREATE INDEX IF NOT EXISTS ON DeviceState (device_id) UNIQUE;

-- -------------------------------------------------------------
-- Vertex: OperationLog
-- Local log of significant operations for diagnostics and
-- on-device intelligence. Older entries can be pruned.
-- -------------------------------------------------------------
CREATE VERTEX TYPE OperationLog IF NOT EXISTS;
ALTER TYPE OperationLog IF NOT EXISTS CREATE PROPERTY operation STRING;
ALTER TYPE OperationLog IF NOT EXISTS CREATE PROPERTY result STRING;
ALTER TYPE OperationLog IF NOT EXISTS CREATE PROPERTY detail STRING;
ALTER TYPE OperationLog IF NOT EXISTS CREATE PROPERTY occurred_at DATETIME;

CREATE INDEX IF NOT EXISTS ON OperationLog (occurred_at) NOTUNIQUE;

-- -------------------------------------------------------------
-- Edge: Performed
-- Links DeviceState to its OperationLog entries.
-- -------------------------------------------------------------
CREATE EDGE TYPE Performed IF NOT EXISTS;
ALTER TYPE Performed IF NOT EXISTS CREATE PROPERTY occurred_at DATETIME;
