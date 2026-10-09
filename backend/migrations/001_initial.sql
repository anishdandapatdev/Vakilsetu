CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE advocate_status AS ENUM ('pending', 'verified', 'rejected', 'suspended');
CREATE TYPE device_status AS ENUM ('pending', 'trusted', 'revoked');
CREATE TYPE conversation_kind AS ENUM ('direct', 'private_group');
CREATE TYPE membership_status AS ENUM ('active', 'removed');

CREATE TABLE accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_e164 text UNIQUE,
  email text UNIQUE,
  password_hash text,
  status advocate_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (phone_e164 IS NOT NULL OR email IS NOT NULL),
  CHECK (password_hash IS NULL OR email IS NOT NULL)
);

CREATE TABLE advocate_profiles (
  account_id uuid PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  full_name text NOT NULL CHECK (char_length(full_name) BETWEEN 2 AND 120),
  enrollment_number text NOT NULL UNIQUE,
  primary_court_id uuid,
  photo_object_key text,
  approved_by uuid REFERENCES accounts(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  status device_status NOT NULL DEFAULT 'pending',
  public_identity_key bytea NOT NULL,
  key_fingerprint text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (account_id, key_fingerprint)
);

CREATE TABLE courts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  city text NOT NULL,
  image_object_key text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE advocate_profiles
  ADD CONSTRAINT advocate_profiles_primary_court_fk
  FOREIGN KEY (primary_court_id) REFERENCES courts(id);

CREATE TABLE conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind conversation_kind NOT NULL,
  title text,
  membership_epoch integer NOT NULL DEFAULT 1 CHECK (membership_epoch > 0),
  created_by uuid NOT NULL REFERENCES accounts(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE conversation_members (
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  status membership_status NOT NULL DEFAULT 'active',
  joined_epoch integer NOT NULL CHECK (joined_epoch > 0),
  removed_epoch integer,
  joined_at timestamptz NOT NULL DEFAULT now(),
  removed_at timestamptz,
  PRIMARY KEY (conversation_id, account_id),
  CHECK ((status = 'active' AND removed_epoch IS NULL AND removed_at IS NULL)
      OR (status = 'removed' AND removed_epoch IS NOT NULL AND removed_at IS NOT NULL))
);

CREATE TABLE encrypted_envelopes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_account_id uuid NOT NULL REFERENCES accounts(id),
  sender_device_id uuid NOT NULL REFERENCES devices(id),
  client_message_id uuid NOT NULL,
  membership_epoch integer NOT NULL CHECK (membership_epoch > 0),
  protocol text NOT NULL,
  ciphertext bytea NOT NULL,
  ciphertext_size integer NOT NULL CHECK (ciphertext_size > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sender_device_id, client_message_id)
);

CREATE INDEX encrypted_envelopes_timeline_idx
  ON encrypted_envelopes (conversation_id, created_at, id);

CREATE TABLE public_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  court_id uuid NOT NULL UNIQUE REFERENCES courts(id),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id uuid NOT NULL REFERENCES public_channels(id) ON DELETE CASCADE,
  author_admin_id uuid NOT NULL REFERENCES accounts(id),
  body text NOT NULL,
  attachment_object_key text,
  revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_account_id uuid REFERENCES accounts(id),
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
