CREATE TABLE admin_principals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('reviewer', 'super_admin')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE admin_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES admin_principals(id) ON DELETE CASCADE,
  token_hash bytea NOT NULL UNIQUE,
  mfa_verified_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE advocate_verification_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  reviewer_admin_id uuid NOT NULL REFERENCES admin_principals(id),
  decision advocate_status NOT NULL CHECK (decision IN ('verified', 'rejected', 'suspended')),
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX advocate_profiles_directory_idx
  ON advocate_profiles (primary_court_id, full_name);

INSERT INTO courts(slug, name, city) VALUES
  ('delhi-high-court', 'Delhi High Court', 'New Delhi'),
  ('saket-district-court', 'Saket District Court', 'New Delhi'),
  ('tis-hazari-courts', 'Tis Hazari Courts', 'New Delhi'),
  ('patiala-house-courts', 'Patiala House Courts', 'New Delhi'),
  ('rouse-avenue-court', 'Rouse Avenue Court', 'New Delhi')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public_channels(court_id)
SELECT id FROM courts ON CONFLICT (court_id) DO NOTHING;
