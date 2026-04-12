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
CREATE PROPERTY DeviceState.device_id IF NOT EXISTS STRING;
CREATE PROPERTY DeviceState.firmware_version IF NOT EXISTS STRING;
CREATE PROPERTY DeviceState.boot_count IF NOT EXISTS LONG;
CREATE PROPERTY DeviceState.last_boot_at IF NOT EXISTS DATETIME;
CREATE PROPERTY DeviceState.status IF NOT EXISTS STRING;

CREATE INDEX IF NOT EXISTS ON DeviceState (device_id) UNIQUE;

-- -------------------------------------------------------------
-- Vertex: OperationLog
-- Local log of significant operations for diagnostics and
-- on-device intelligence. Older entries can be pruned.
-- -------------------------------------------------------------
CREATE VERTEX TYPE OperationLog IF NOT EXISTS;
CREATE PROPERTY OperationLog.operation IF NOT EXISTS STRING;
CREATE PROPERTY OperationLog.result IF NOT EXISTS STRING;
CREATE PROPERTY OperationLog.detail IF NOT EXISTS STRING;
CREATE PROPERTY OperationLog.occurred_at IF NOT EXISTS DATETIME;

CREATE INDEX IF NOT EXISTS ON OperationLog (occurred_at) NOTUNIQUE;

-- -------------------------------------------------------------
-- Edge: Performed
-- Links DeviceState to its OperationLog entries.
-- -------------------------------------------------------------
CREATE EDGE TYPE Performed IF NOT EXISTS;
CREATE PROPERTY Performed.occurred_at IF NOT EXISTS DATETIME;
