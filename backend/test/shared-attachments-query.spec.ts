import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { SharedAttachmentsQueryDto } from '../src/modules/attachments/dto/shared-attachments-query.dto';

describe('shared attachment search query', () => {
  it('accepts a bounded file search and type', async () => {
    const query = plainToInstance(SharedAttachmentsQueryDto,
      { search: 'petition', kind: 'pdf', limit: '25' });
    expect(await validate(query)).toHaveLength(0);
    expect(query.limit).toBe(25);
  });

  it.each([
    { search: 'a'.repeat(101) },
    { kind: 'exe' },
    { limit: 101 },
    { before: 'invalid' },
  ])('rejects invalid filters %#', async input => {
    const query = plainToInstance(SharedAttachmentsQueryDto, input);
    expect((await validate(query)).length).toBeGreaterThan(0);
  });
});
