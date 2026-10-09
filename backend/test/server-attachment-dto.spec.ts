import { validate } from 'class-validator';
import { ServerAttachmentDto } from '../src/modules/attachments/dto/server-attachment.dto';

describe('server-readable attachment input', () => {
  const value = (overrides: Partial<ServerAttachmentDto> = {}) => Object.assign(
    new ServerAttachmentDto(), {
      filename: 'petition.pdf', contentType: 'application/pdf', byteSize: 2048,
      sha256: 'a'.repeat(64), ...overrides,
    });
  it('accepts supported files', async () => expect(await validate(value())).toHaveLength(0));
  it.each([
    { filename: '../petition.pdf' },
    { contentType: 'text/html' },
    { byteSize: 25 * 1024 * 1024 + 1 },
    { sha256: 'bad' },
  ])('rejects unsafe metadata %#', async overrides => {
    expect((await validate(value(overrides))).length).toBeGreaterThan(0);
  });
});
