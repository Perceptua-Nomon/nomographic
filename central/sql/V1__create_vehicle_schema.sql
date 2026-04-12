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
CREATE PROPERTY Vehicle.vin IF NOT EXISTS STRING;
CREATE PROPERTY Vehicle.model IF NOT EXISTS STRING;
CREATE PROPERTY Vehicle.firmware_version IF NOT EXISTS STRING;
CREATE PROPERTY Vehicle.registered_at IF NOT EXISTS DATETIME;
CREATE PROPERTY Vehicle.last_seen_at IF NOT EXISTS DATETIME;

CREATE INDEX IF NOT EXISTS ON Vehicle (vin) UNIQUE;

-- -------------------------------------------------------------
-- Vertex: TelemetryReading
-- A single telemetry snapshot from a nomon device.
-- -------------------------------------------------------------
CREATE VERTEX TYPE TelemetryReading IF NOT EXISTS;
CREATE PROPERTY TelemetryReading.battery_voltage IF NOT EXISTS DOUBLE;
CREATE PROPERTY TelemetryReading.cpu_temp_c IF NOT EXISTS DOUBLE;
CREATE PROPERTY TelemetryReading.uptime_seconds IF NOT EXISTS LONG;
CREATE PROPERTY TelemetryReading.recorded_at IF NOT EXISTS DATETIME;

CREATE INDEX IF NOT EXISTS ON TelemetryReading (recorded_at) NOTUNIQUE;

-- -------------------------------------------------------------
-- Edge: HasTelemetry
-- Links a Vehicle to its TelemetryReading entries.
-- -------------------------------------------------------------
CREATE EDGE TYPE HasTelemetry IF NOT EXISTS;
CREATE PROPERTY HasTelemetry.recorded_at IF NOT EXISTS DATETIME;
