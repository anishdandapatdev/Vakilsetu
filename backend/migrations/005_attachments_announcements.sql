CREATE TYPE attachment_status AS ENUM ('pending', 'available', 'deleted');

CREATE TABLE encrypted_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  uploader_account_id uuid NOT NULL REFERENCES accounts(id),
  uploader_device_id uuid NOT NULL REFERENCES devices(id),
  membership_epoch integer NOT NULL CHECK (membership_epoch > 0),
  object_key text NOT NULL UNIQUE,
  ciphertext_size bigint NOT NULL CHECK (ciphertext_size BETWEEN 1 AND 104857600),
  ciphertext_sha256 bytea NOT NULL,
  status attachment_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  available_at timestamptz
);

CREATE INDEX encrypted_attachments_conversation_idx
  ON encrypted_attachments (conversation_id, created_at DESC);

CREATE TABLE public_announcement_revisions (
  announcement_id uuid NOT NULL REFERENCES public_announcements(id) ON DELETE CASCADE,
  revision integer NOT NULL,
  body text NOT NULL,
  attachment_object_key text,
  editor_admin_id uuid NOT NULL REFERENCES admin_principals(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (announcement_id, revision)
);

ALTER TABLE public_announcements
  DROP CONSTRAINT public_announcements_author_admin_id_fkey,
  ADD CONSTRAINT public_announcements_author_admin_fk
    FOREIGN KEY (author_admin_id) REFERENCES admin_principals(id);

ALTER TABLE public_announcements
  ADD COLUMN published boolean NOT NULL DEFAULT true,
  ADD COLUMN deleted_at timestamptz;
