CREATE TABLE court_subscriptions (
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  court_id uuid NOT NULL REFERENCES courts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, court_id)
);

CREATE INDEX court_subscriptions_account_idx
  ON court_subscriptions(account_id, created_at DESC);
