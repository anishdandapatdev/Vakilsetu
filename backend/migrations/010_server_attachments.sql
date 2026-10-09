CREATE TABLE server_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  uploader_account_id uuid NOT NULL REFERENCES accounts(id),
  object_key text NOT NULL UNIQUE,
  filename text NOT NULL CHECK (length(filename) BETWEEN 1 AND 180),
  content_type text NOT NULL CHECK (length(content_type) BETWEEN 3 AND 100),
  byte_size bigint NOT NULL CHECK (byte_size BETWEEN 1 AND 26214400),
  sha256 bytea NOT NULL,
  status attachment_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  available_at timestamptz
);
ALTER TABLE server_messages DROP CONSTRAINT server_messages_body_check;
ALTER TABLE server_messages ADD COLUMN attachment_id uuid REFERENCES server_attachments(id);
ALTER TABLE server_messages ADD CONSTRAINT server_messages_content_check
  CHECK (length(body) <= 4000 AND (length(trim(body)) > 0 OR attachment_id IS NOT NULL));
