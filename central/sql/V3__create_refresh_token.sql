-- V3: Refresh token storage for JWT session management.
-- Supports token rotation, per-user revocation, and TTL-based cleanup.

CREATE VERTEX TYPE RefreshToken IF NOT EXISTS;

CREATE PROPERTY RefreshToken.token_hash IF NOT EXISTS STRING;
CREATE PROPERTY RefreshToken.email IF NOT EXISTS STRING;
CREATE PROPERTY RefreshToken.created_at IF NOT EXISTS STRING;
CREATE PROPERTY RefreshToken.expires_at IF NOT EXISTS STRING;

CREATE INDEX IF NOT EXISTS ON RefreshToken (token_hash) UNIQUE;
CREATE INDEX IF NOT EXISTS ON RefreshToken (email) NOTUNIQUE;
CREATE INDEX IF NOT EXISTS ON RefreshToken (expires_at) NOTUNIQUE;
