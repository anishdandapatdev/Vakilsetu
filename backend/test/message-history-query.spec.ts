import 'reflect-metadata';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { MessageHistoryQueryDto } from '../src/modules/messaging/dto/message-history-query.dto';

describe('message history query', () => {
  it('uses the compact default page size', async () => {
    const query = plainToInstance(MessageHistoryQueryDto, {});
    expect(query.limit).toBe(50);
    expect(await validate(query)).toHaveLength(0);
  });
  it('transforms and accepts bounded pagination', async () => {
    const query = plainToInstance(MessageHistoryQueryDto, {
      limit: '100', before: 'fa9baa82-d347-4c29-8c56-510341d3624a',
    });
    expect(query.limit).toBe(100);
    expect(await validate(query)).toHaveLength(0);
  });
  it.each(['0', '101'])('rejects page size %s', async limit => {
    expect((await validate(plainToInstance(MessageHistoryQueryDto, { limit }))).length)
      .toBeGreaterThan(0);
  });
});
