-- V3: Refresh token storage for JWT session management.
-- Supports token rotation, per-user revocation, and TTL-based cleanup.

CREATE VERTEX TYPE RefreshToken IF NOT EXISTS;

ALTER TYPE RefreshToken IF NOT EXISTS CREATE PROPERTY token_hash STRING;
ALTER TYPE RefreshToken IF NOT EXISTS CREATE PROPERTY email STRING;
ALTER TYPE RefreshToken IF NOT EXISTS CREATE PROPERTY created_at STRING;
ALTER TYPE RefreshToken IF NOT EXISTS CREATE PROPERTY expires_at STRING;

CREATE INDEX IF NOT EXISTS ON RefreshToken (token_hash) UNIQUE;
CREATE INDEX IF NOT EXISTS ON RefreshToken (email) NOTUNIQUE;
CREATE INDEX IF NOT EXISTS ON RefreshToken (expires_at) NOTUNIQUE;
