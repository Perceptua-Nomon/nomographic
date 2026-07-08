-- =============================================================
-- V4: Add autonomy run/event schema for autonomy telemetry
-- =============================================================
-- Persists autonomy routine runs and their lifecycle events, as
-- reported by the brain (autonomon) to its device and forwarded
-- to central over MQTT (autonomon Phase 7).
-- Relationships: an AutonomyRun links to its Vehicle via a
-- PerformedBy edge; an AutonomyEvent links to its AutonomyRun via
-- a PartOf edge.
-- AutonomyRun.vin is denormalised (also reachable via PerformedBy)
-- so run/event queries can be ownership-scoped without a traversal.

-- -------------------------------------------------------------
-- Vertex: AutonomyRun
-- One run of an autonomy routine on a device.
-- -------------------------------------------------------------
CREATE VERTEX TYPE AutonomyRun IF NOT EXISTS;
CREATE PROPERTY AutonomyRun.run_id IF NOT EXISTS STRING;
ALTER PROPERTY AutonomyRun.run_id MANDATORY true;
ALTER PROPERTY AutonomyRun.run_id NOTNULL true;
CREATE PROPERTY AutonomyRun.vin IF NOT EXISTS STRING;
ALTER PROPERTY AutonomyRun.vin MANDATORY true;
ALTER PROPERTY AutonomyRun.vin NOTNULL true;
CREATE PROPERTY AutonomyRun.routine IF NOT EXISTS STRING;
ALTER PROPERTY AutonomyRun.routine MANDATORY true;
ALTER PROPERTY AutonomyRun.routine NOTNULL true;
CREATE PROPERTY AutonomyRun.status IF NOT EXISTS STRING;
ALTER PROPERTY AutonomyRun.status MANDATORY true;
ALTER PROPERTY AutonomyRun.status NOTNULL true;
-- Timestamps are DATETIME. Values must be formatted to ArcadeDB's
-- 'yyyy-MM-dd HH:mm:ss' (UTC) before binding — the Python store does this via
-- db_utils.to_db_datetime / db_datetime_to_iso (a raw ISO-8601 offset string
-- would be stored as null). Same convention as User/RefreshToken timestamps.
CREATE PROPERTY AutonomyRun.started_at IF NOT EXISTS DATETIME;
ALTER PROPERTY AutonomyRun.started_at MANDATORY true;
ALTER PROPERTY AutonomyRun.started_at NOTNULL true;
CREATE PROPERTY AutonomyRun.updated_at IF NOT EXISTS DATETIME;
ALTER PROPERTY AutonomyRun.updated_at MANDATORY true;
ALTER PROPERTY AutonomyRun.updated_at NOTNULL true;
CREATE PROPERTY AutonomyRun.ended_at IF NOT EXISTS DATETIME;

CREATE INDEX IF NOT EXISTS ON AutonomyRun (run_id) UNIQUE;
CREATE INDEX IF NOT EXISTS ON AutonomyRun (vin) NOTUNIQUE;

-- -------------------------------------------------------------
-- Vertex: AutonomyEvent
-- A single lifecycle event reported during an autonomy run.
-- data_json holds the event's payload verbatim (JSON string) —
-- central stores exactly what the brain reported (ADR-004).
-- -------------------------------------------------------------
CREATE VERTEX TYPE AutonomyEvent IF NOT EXISTS;
CREATE PROPERTY AutonomyEvent.event_type IF NOT EXISTS STRING;
ALTER PROPERTY AutonomyEvent.event_type MANDATORY true;
ALTER PROPERTY AutonomyEvent.event_type NOTNULL true;
CREATE PROPERTY AutonomyEvent.data_json IF NOT EXISTS STRING;
-- DATETIME, same UTC formatting convention as AutonomyRun timestamps above.
CREATE PROPERTY AutonomyEvent.recorded_at IF NOT EXISTS DATETIME;
ALTER PROPERTY AutonomyEvent.recorded_at MANDATORY true;
ALTER PROPERTY AutonomyEvent.recorded_at NOTNULL true;

CREATE INDEX IF NOT EXISTS ON AutonomyEvent (recorded_at) NOTUNIQUE;

-- -------------------------------------------------------------
-- Edge: PerformedBy
-- Links an AutonomyRun to the Vehicle it ran on.
-- -------------------------------------------------------------
CREATE EDGE TYPE PerformedBy IF NOT EXISTS;

-- -------------------------------------------------------------
-- Edge: PartOf
-- Links an AutonomyEvent to the AutonomyRun it belongs to.
-- -------------------------------------------------------------
CREATE EDGE TYPE PartOf IF NOT EXISTS;
