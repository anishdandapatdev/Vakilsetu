import { validate } from 'class-validator';
import { EditMessageDto } from '../src/modules/messaging/dto/edit-message.dto';

describe('message edit input', () => {
  it('accepts meaningful text', async () => {
    const input = Object.assign(new EditMessageDto(), { body: 'Updated text' });
    expect(await validate(input)).toHaveLength(0);
  });

  it.each(['', '   ', 'x'.repeat(4001)])('rejects invalid text', async body => {
    const input = Object.assign(new EditMessageDto(), { body });
    expect((await validate(input)).length).toBeGreaterThan(0);
  });
});
