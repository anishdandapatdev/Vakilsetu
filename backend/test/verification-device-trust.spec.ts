import { VerificationController } from '../src/modules/admin/verification.controller';
import { DatabaseService } from '../src/platform/database/database.service';
import { AdminRequest } from '../src/modules/admin/admin-session.guard';

const accountId = '11111111-1111-4111-8111-111111111111';
const deviceId = '22222222-2222-4222-8222-222222222222';
const request = { adminIdentity: { adminId: '33333333-3333-4333-8333-333333333333' } } as AdminRequest;

describe('advocate verification device bootstrap', () => {
  function setup(hasTrustedDevice = false) {
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('FROM advocate_profiles')) return { rowCount: 1, rows: [{ exists: 1 }] };
      if (sql.includes("status = 'trusted' LIMIT 1")) return { rowCount: hasTrustedDevice ? 1 : 0, rows: [] };
      if (sql.includes("status = 'pending' ORDER BY")) return { rowCount: 1, rows: [{ id: deviceId }] };
      return { rowCount: 1, rows: [] };
    });
    const database = { transaction: (fn: (client: { query: typeof query }) => unknown) => fn({ query }) };
    return { controller: new VerificationController(database as unknown as DatabaseService), query };
  }

  it('trusts the first pending device when an admin verifies the advocate', async () => {
    const { controller, query } = setup();
    await controller.decide(accountId, { decision: 'verified' }, request);
    expect(query).toHaveBeenCalledWith("UPDATE devices SET status = 'trusted' WHERE id = $1", [deviceId]);
    expect(query.mock.calls.some(([sql]) => sql.includes("'device.trusted'"))).toBe(true);
  });

  it('does not trust another device when one is already trusted', async () => {
    const { controller, query } = setup(true);
    await controller.decide(accountId, { decision: 'verified' }, request);
    expect(query.mock.calls.some(([sql]) => sql.includes("UPDATE devices SET status = 'trusted'"))).toBe(false);
  });

  it('does not trust a device when verification is rejected', async () => {
    const { controller, query } = setup();
    await controller.decide(accountId, { decision: 'rejected' }, request);
    expect(query.mock.calls.some(([sql]) => sql.includes("UPDATE devices SET status = 'trusted'"))).toBe(false);
  });
});
