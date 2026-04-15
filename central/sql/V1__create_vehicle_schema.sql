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
ALTER PROPERTY Vehicle.vin MANDATORY true;
ALTER PROPERTY Vehicle.vin NOTNULL true;
CREATE PROPERTY Vehicle.model IF NOT EXISTS STRING;
ALTER PROPERTY Vehicle.model MANDATORY true;
ALTER PROPERTY Vehicle.model NOTNULL true;
CREATE PROPERTY Vehicle.firmware_version IF NOT EXISTS STRING;
ALTER PROPERTY Vehicle.firmware_version MANDATORY true;
CREATE PROPERTY Vehicle.registered_at IF NOT EXISTS DATETIME;
ALTER PROPERTY Vehicle.registered_at MANDATORY true;
ALTER PROPERTY Vehicle.registered_at NOTNULL true;
CREATE PROPERTY Vehicle.last_seen_at IF NOT EXISTS DATETIME;
ALTER PROPERTY Vehicle.last_seen_at MANDATORY true;

CREATE INDEX IF NOT EXISTS ON Vehicle (vin) UNIQUE;

-- -------------------------------------------------------------
-- Vertex: TelemetryReading
-- A single telemetry snapshot from a nomon device.
-- -------------------------------------------------------------
CREATE VERTEX TYPE TelemetryReading IF NOT EXISTS;
CREATE PROPERTY TelemetryReading.battery_voltage IF NOT EXISTS DOUBLE;
ALTER PROPERTY TelemetryReading.battery_voltage NOTNULL true;
CREATE PROPERTY TelemetryReading.cpu_temp_c IF NOT EXISTS DOUBLE;
ALTER PROPERTY TelemetryReading.cpu_temp_c NOTNULL true;
CREATE PROPERTY TelemetryReading.uptime_seconds IF NOT EXISTS LONG;
ALTER PROPERTY TelemetryReading.uptime_seconds NOTNULL true;
CREATE PROPERTY TelemetryReading.recorded_at IF NOT EXISTS DATETIME;
ALTER PROPERTY TelemetryReading.recorded_at MANDATORY true;
ALTER PROPERTY TelemetryReading.recorded_at NOTNULL true;

CREATE INDEX IF NOT EXISTS ON TelemetryReading (recorded_at) NOTUNIQUE;

-- -------------------------------------------------------------
-- Edge: ReadFrom
-- Links a TelemetryReading to the Vehicle it was read from.
-- -------------------------------------------------------------
CREATE EDGE TYPE ReadFrom IF NOT EXISTS;
