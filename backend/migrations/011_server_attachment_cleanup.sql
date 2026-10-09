ALTER TABLE server_attachments
  ADD COLUMN cleanup_attempted_at timestamptz,
  ADD COLUMN cleanup_error text;

CREATE INDEX server_attachments_cleanup
  ON server_attachments(status, created_at)
  WHERE status IN ('pending', 'available');
