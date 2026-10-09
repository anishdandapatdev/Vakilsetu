import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { ServerAttachmentsService } from '../src/modules/attachments/server-attachments.service';
import { RequestIdentity } from '../src/modules/identity/session.policy';
import { DatabaseService } from '../src/platform/database/database.service';
import { SessionPolicy } from '../src/modules/identity/session.policy';
import { ObjectStorage } from '../src/platform/storage/object-storage';
import { MalwareScanner } from '../src/platform/security/malware-scanner';

describe('shared attachment index', () => {
  const identity: RequestIdentity = {
    accountId: 'account-1', deviceId: 'device-1',
    advocateStatus: 'verified', deviceStatus: 'trusted',
  };
  const rows = [
    { id: 'attachment-1', messageId: 'message-1' },
    { id: 'attachment-2', messageId: 'message-2' },
  ];
  const query = jest.fn().mockResolvedValue({ rows });
  const policy = { assertPrivateMessagingAllowed: jest.fn() };
  const service = new ServerAttachmentsService(
    { query } as unknown as DatabaseService,
    policy as unknown as SessionPolicy,
    {} as ObjectStorage,
    {} as MalwareScanner,
  );

  beforeEach(() => {
    query.mockClear();
    policy.assertPrivateMessagingAllowed.mockReset();
  });

  it('pages only clean, undeleted attachments in active conversations', async () => {
    const page = await service.listShared(identity, 'cursor-1', 2, 'Petition', 'pdf');
    expect(page.items).toEqual(rows);
    expect(page.nextCursor).toBe('message-2');
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("self.account_id=$1 AND self.status='active'"),
      ['account-1', 'cursor-1', 2, 'Petition', 'pdf'],
    );
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain("a.scan_status='clean'");
    expect(sql).toContain('msg.deleted_at IS NULL');
    expect(sql).toContain("cursor_member.status='active'");
    expect(sql).toContain('strpos(lower(a.filename), lower($4::text))');
    expect(sql).toContain("$5::text='pdf'");
  });

  it('rejects callers who cannot use private messaging', async () => {
    policy.assertPrivateMessagingAllowed.mockImplementation(() => {
      throw new ForbiddenException('verified_advocate_required');
    });
    await expect(service.listShared(identity, undefined, 50)).rejects.toThrow(ForbiddenException);
    expect(query).not.toHaveBeenCalled();
  });

  it('does not offer an unlinked or deleted message attachment for download', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    await expect(service.download(identity, 'attachment-1')).rejects.toThrow(NotFoundException);
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain('msg.attachment_id=a.id AND msg.deleted_at IS NULL');
    expect(sql).toContain("a.scan_status='clean'");
  });
});
