CREATE TABLE blocked_accounts (
  blocker_account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  blocked_account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_account_id, blocked_account_id),
  CHECK (blocker_account_id <> blocked_account_id)
);

CREATE TABLE direct_conversation_pairs (
  lower_account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  upper_account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL UNIQUE REFERENCES conversations(id) ON DELETE CASCADE,
  PRIMARY KEY (lower_account_id, upper_account_id),
  CHECK (lower_account_id::text < upper_account_id::text)
);

ALTER TABLE conversation_members
  ADD COLUMN member_role text NOT NULL DEFAULT 'member'
  CHECK (member_role IN ('owner', 'member'));

ALTER TABLE encrypted_envelopes
  ADD COLUMN recipient_device_id uuid NOT NULL REFERENCES devices(id),
  ADD COLUMN ciphertext_hash bytea NOT NULL;

ALTER TABLE encrypted_envelopes
  DROP CONSTRAINT encrypted_envelopes_sender_device_id_client_message_id_key,
  ADD CONSTRAINT encrypted_envelopes_sender_recipient_message_unique
    UNIQUE (sender_device_id, recipient_device_id, client_message_id);

CREATE INDEX encrypted_envelopes_recipient_timeline_idx
  ON encrypted_envelopes (recipient_device_id, created_at, id);
