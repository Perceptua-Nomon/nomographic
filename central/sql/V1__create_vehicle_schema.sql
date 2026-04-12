-- =============================================================
-- V1: Create core vehicle schema for the nomon central database
-- =============================================================
-- Establishes the foundational vertex types for fleet management:
-- Vehicle, TelemetryReading, and their connecting edge type.

-- -------------------------------------------------------------
-- Vertex: Vehicle
-- Represents a single nomon robot in the fleet.
-- -------------------------------------------------------------
CREATE VERTEX TYPE Vehicle IF NOT EXISTS;
ALTER TYPE Vehicle IF NOT EXISTS CREATE PROPERTY vin STRING;
ALTER TYPE Vehicle IF NOT EXISTS CREATE PROPERTY model STRING;
ALTER TYPE Vehicle IF NOT EXISTS CREATE PROPERTY firmware_version STRING;
ALTER TYPE Vehicle IF NOT EXISTS CREATE PROPERTY registered_at DATETIME;
ALTER TYPE Vehicle IF NOT EXISTS CREATE PROPERTY last_seen_at DATETIME;

CREATE INDEX IF NOT EXISTS ON Vehicle (vin) UNIQUE;

-- -------------------------------------------------------------
-- Vertex: TelemetryReading
-- A single telemetry snapshot from a nomon device.
-- -------------------------------------------------------------
CREATE VERTEX TYPE TelemetryReading IF NOT EXISTS;
ALTER TYPE TelemetryReading IF NOT EXISTS CREATE PROPERTY battery_voltage DOUBLE;
ALTER TYPE TelemetryReading IF NOT EXISTS CREATE PROPERTY cpu_temp_c DOUBLE;
ALTER TYPE TelemetryReading IF NOT EXISTS CREATE PROPERTY uptime_seconds LONG;
ALTER TYPE TelemetryReading IF NOT EXISTS CREATE PROPERTY recorded_at DATETIME;

CREATE INDEX IF NOT EXISTS ON TelemetryReading (recorded_at) NOTUNIQUE;

-- -------------------------------------------------------------
-- Edge: HasTelemetry
-- Links a Vehicle to its TelemetryReading entries.
-- -------------------------------------------------------------
CREATE EDGE TYPE HasTelemetry IF NOT EXISTS;
ALTER TYPE HasTelemetry IF NOT EXISTS CREATE PROPERTY recorded_at DATETIME;
