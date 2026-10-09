ALTER TABLE encrypted_envelopes
  ADD COLUMN received_at timestamptz,
  ADD COLUMN acknowledged_at timestamptz;

CREATE TABLE push_registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('fcm', 'apns', 'webpush')),
  token_ciphertext bytea NOT NULL,
  token_iv bytea NOT NULL,
  token_tag bytea NOT NULL,
  token_fingerprint bytea NOT NULL,
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (device_id, provider, token_fingerprint)
);

CREATE TABLE opaque_delivery_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  envelope_id uuid NOT NULL REFERENCES encrypted_envelopes(id) ON DELETE CASCADE,
  push_status text NOT NULL DEFAULT 'pending'
    CHECK (push_status IN ('pending', 'sent', 'failed', 'suppressed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (recipient_device_id, envelope_id)
);

CREATE INDEX opaque_delivery_events_pending_idx
  ON opaque_delivery_events (created_at)
  WHERE push_status = 'pending';
