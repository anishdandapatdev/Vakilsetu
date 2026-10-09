// Local smoke-test fixture only. Never point this script at a shared database.
require('dotenv').config();
const { Client } = require('pg');

async function main() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('This fixture cannot run in production.');
  }
  const databaseUrl = new URL(process.env.DATABASE_URL);
  if (!['127.0.0.1', 'localhost'].includes(databaseUrl.hostname)) {
    throw new Error('This fixture requires a loopback database.');
  }
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    const accounts = await client.query(
      `UPDATE accounts SET status = 'verified'
       WHERE phone_e164 = ANY($1::text[]) AND status = 'pending'
       RETURNING id`,
      [['+919000000004', '+919000000005']],
    );
    const devices = await client.query(
      `UPDATE devices SET status = 'trusted'
       WHERE account_id = ANY($1::uuid[]) AND status = 'pending'
       RETURNING id`,
      [accounts.rows.map((row) => row.id)],
    );
    console.log(JSON.stringify({
      testAccountsVerified: accounts.rowCount,
      testDevicesTrusted: devices.rowCount,
    }));
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
