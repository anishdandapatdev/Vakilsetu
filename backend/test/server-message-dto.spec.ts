import { validate } from 'class-validator';
import { ServerMessageDto } from '../src/modules/messaging/dto/server-message.dto';

describe('server-readable message input', () => {
  const input = (body: string, clientMessageId = 'fa9baa82-d347-4c29-8c56-510341d3624a') =>
    Object.assign(new ServerMessageDto(), { body, clientMessageId });
  it('accepts text and retry UUID', async () => {
    expect(await validate(input('Hello'))).toHaveLength(0);
  });
  it.each(['', '   ', 'x'.repeat(4001)])('rejects empty or oversized text', async body => {
    expect((await validate(input(body))).length).toBeGreaterThan(0);
  });
  it('rejects invalid request IDs', async () => {
    expect((await validate(input('Hello', 'bad'))).length).toBeGreaterThan(0);
  });
  it('accepts an attachment without text', async () => {
    const value = Object.assign(new ServerMessageDto(), {
      clientMessageId: 'fa9baa82-d347-4c29-8c56-510341d3624a',
      attachmentId: 'dd03fce4-80f8-4ab6-bf75-1aab2cb9230c',
    });
    expect(await validate(value)).toHaveLength(0);
  });
  it('accepts a valid reply target and rejects an invalid one', async () => {
    const valid = Object.assign(input('Reply'), {
      replyToMessageId: 'dd03fce4-80f8-4ab6-bf75-1aab2cb9230c',
    });
    expect(await validate(valid)).toHaveLength(0);
    const invalid = Object.assign(input('Reply'), { replyToMessageId: 'bad' });
    expect((await validate(invalid)).length).toBeGreaterThan(0);
  });
});
