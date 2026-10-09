ALTER TABLE server_messages
  DROP CONSTRAINT server_messages_content_check,
  ALTER COLUMN body DROP NOT NULL,
  ADD COLUMN reply_to_message_id uuid REFERENCES server_messages(id) ON DELETE SET NULL,
  ADD COLUMN edited_at timestamptz,
  ADD COLUMN deleted_at timestamptz,
  ADD CONSTRAINT server_messages_body_state_check CHECK (
    (deleted_at IS NULL AND COALESCE(length(body), 0) <= 4000
      AND (COALESCE(length(trim(body)), 0) > 0 OR attachment_id IS NOT NULL))
    OR (deleted_at IS NOT NULL AND body IS NULL AND attachment_id IS NULL)
  );

CREATE INDEX server_messages_reply_lookup
  ON server_messages(reply_to_message_id)
  WHERE reply_to_message_id IS NOT NULL;
