CREATE INDEX server_messages_retention
  ON server_messages(created_at, id);
