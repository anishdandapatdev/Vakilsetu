import { validate } from 'class-validator';
import { ReadMessagesDto } from '../src/modules/messaging/dto/read-messages.dto';

describe('read receipt input', () => {
  it('accepts a message UUID boundary', async () => {
    const value = Object.assign(new ReadMessagesDto(), {
      throughMessageId: 'fa9baa82-d347-4c29-8c56-510341d3624a',
    });
    expect(await validate(value)).toHaveLength(0);
  });
  it('rejects malformed boundaries', async () => {
    const value = Object.assign(new ReadMessagesDto(), { throughMessageId: 'latest' });
    expect((await validate(value)).length).toBeGreaterThan(0);
  });
});
