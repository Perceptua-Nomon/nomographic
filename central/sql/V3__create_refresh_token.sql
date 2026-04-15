-- V3: Refresh token storage for JWT session management.
-- Supports token rotation, per-user revocation, and TTL-based cleanup.

CREATE VERTEX TYPE RefreshToken IF NOT EXISTS;

CREATE PROPERTY RefreshToken.token_hash IF NOT EXISTS STRING;
ALTER PROPERTY RefreshToken.token_hash MANDATORY true;
ALTER PROPERTY RefreshToken.token_hash NOTNULL true;
CREATE PROPERTY RefreshToken.email IF NOT EXISTS STRING;
ALTER PROPERTY RefreshToken.email MANDATORY true;
ALTER PROPERTY RefreshToken.email NOTNULL true;
CREATE PROPERTY RefreshToken.created_at IF NOT EXISTS DATETIME;
ALTER PROPERTY RefreshToken.created_at MANDATORY true;
ALTER PROPERTY RefreshToken.created_at NOTNULL true;
CREATE PROPERTY RefreshToken.expires_at IF NOT EXISTS DATETIME;
ALTER PROPERTY RefreshToken.expires_at MANDATORY true;
ALTER PROPERTY RefreshToken.expires_at NOTNULL true;

CREATE INDEX IF NOT EXISTS ON RefreshToken (token_hash) UNIQUE;
CREATE INDEX IF NOT EXISTS ON RefreshToken (email) NOTUNIQUE;
CREATE INDEX IF NOT EXISTS ON RefreshToken (expires_at) NOTUNIQUE;
