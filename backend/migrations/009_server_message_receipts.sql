CREATE TABLE server_message_receipts (
  message_id uuid NOT NULL REFERENCES server_messages(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES accounts(id),
  delivered_at timestamptz,
  read_at timestamptz,
  PRIMARY KEY (message_id, account_id)
);
CREATE INDEX server_message_receipts_account
  ON server_message_receipts(account_id, message_id);
