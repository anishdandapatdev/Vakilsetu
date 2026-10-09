-- Deliberately server-readable text. Never store these rows as encrypted envelopes.
CREATE TABLE server_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(id),
  sender_account_id uuid NOT NULL REFERENCES accounts(id),
  client_message_id uuid NOT NULL,
  body text NOT NULL CHECK (length(trim(body)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (conversation_id, sender_account_id, client_message_id)
);
CREATE INDEX server_messages_history ON server_messages(conversation_id, created_at, id);
