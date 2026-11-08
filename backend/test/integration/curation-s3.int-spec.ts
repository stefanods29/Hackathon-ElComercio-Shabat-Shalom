import {
  CreateBucketCommand,
  DeleteBucketCommand,
  DeleteObjectsCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import type { INestApplication } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS, NEIGHBOR_ZONE } from '../../scripts/seed-data.js';
import {
  directorySchema,
  indexSchema,
} from '../../src/modules/curaduria/application/directory-schema.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createTestApp } from '../support/app.js';

const endpoint = process.env.CURATION_TEST_S3_ENDPOINT;
const districtFiles = ['lince-demo.json', 'jesus-maria-demo.json'];
const indexKey = 'emergencia/indice.json';
const fixtureRoot = new URL('../../../infra/cdn/publico/emergencia/', import.meta.url);

describe.skipIf(!endpoint)('Curaduría por HTTP, PostgreSQL y MinIO', () => {
  const bucket = `vecinal-directorio-${randomUUID()}`;
  let client: S3Client;
  let app: INestApplication | undefined;
  let created = false;

  beforeAll(async () => {
    const accessKeyId = process.env.CURATION_TEST_S3_ACCESS_KEY_ID!;
    const secretAccessKey = process.env.CURATION_TEST_S3_SECRET_ACCESS_KEY!;
    const region = 'us-east-1';
    client = new S3Client({
      endpoint,
      region,
      credentials: { accessKeyId, secretAccessKey },
      forcePathStyle: true,
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
    });
    await client.send(new CreateBucketCommand({ Bucket: bucket }));
    created = true;
    ({ app } = await createTestApp(inject('databaseUrl'), {
      CURATION_PUBLISH_DRIVER: 's3',
      CURATION_BUCKET: bucket,
      CURATION_ENDPOINT: endpoint!,
      CURATION_REGION: region,
      CURATION_FORCE_PATH_STYLE: 'true',
      CURATION_ACCESS_KEY_ID: accessKeyId,
      CURATION_SECRET_ACCESS_KEY: secretAccessKey,
    }));
  });

  afterAll(async () => {
    await app?.close();
    try {
      if (created) {
        await client.send(
          new DeleteObjectsCommand({
            Bucket: bucket,
            Delete: {
              Objects: [indexKey, ...districtFiles.map((name) => `emergencia/${name}`)].map(
                (Key) => ({ Key }),
              ),
            },
          }),
        );
        await client.send(new DeleteBucketCommand({ Bucket: bucket }));
      }
    } finally {
      client?.destroy();
    }
  });

  it('publica dos distritos sin perder sus cambios en el índice compartido', async () => {
    const server = request(app!.getHttpServer());
    const { id, zoneId, trustLevel } = NEIGHBORS.carla;
    const { token } = await app!.get(TokenService).issueAccess({
      id,
      zoneId,
      trustLevel,
      roles: ['coordinador'],
      sessionId: randomUUID(),
    });
    const route = '/v1/operacion/directorio-emergencia';
    await server.get(route).auth(token, { type: 'bearer' }).expect(503);

    const seed = indexSchema.parse(
      JSON.parse(await readFile(new URL('indice.json', fixtureRoot), 'utf8')),
    );
    seed.distritos.push({
      ...seed.distritos[0]!,
      id: 'jesus-maria-demo',
      archivo: districtFiles[1]!,
      zonas: [NEIGHBOR_ZONE.id],
    });
    await client.send(
      new PutObjectCommand({ Bucket: bucket, Key: indexKey, Body: JSON.stringify(seed) }),
    );
    const { entradas } = directorySchema.parse(
      JSON.parse(await readFile(new URL(districtFiles[0]!, fixtureRoot), 'utf8')),
    );
    await Promise.all(
      districtFiles.map((name) =>
        server
          .put(`${route}/${name}`)
          .auth(token, { type: 'bearer' })
          .set('Idempotency-Key', randomUUID())
          .send({ versionVista: 1, distrito: name.split('.')[0], entradas })
          .expect(200),
      ),
    );

    const publishedIndex = await client.send(
      new GetObjectCommand({ Bucket: bucket, Key: indexKey }),
    );
    expect(publishedIndex.CacheControl).toBe('public, max-age=60');
    expect(publishedIndex.ContentType).toBe('application/json');
    const index = indexSchema.parse(JSON.parse(await publishedIndex.Body!.transformToString()));
    expect(index.distritos.map(({ archivo, version }) => [archivo, version])).toEqual(
      districtFiles.map((name) => [name, 2]),
    );
    for (const entry of index.distritos) {
      const result = await client.send(
        new GetObjectCommand({ Bucket: bucket, Key: `emergencia/${entry.archivo}` }),
      );
      expect(result.CacheControl).toBe('no-cache');
      expect(result.ContentType).toBe('application/json');
      const body = Buffer.from(await result.Body!.transformToByteArray());
      expect(body.length).toBe(entry.bytes);
      expect(createHash('sha256').update(body).digest('hex')).toBe(entry.sha256);
      expect(directorySchema.parse(JSON.parse(body.toString('utf8'))).version).toBe(entry.version);
      await server.get(`${route}/${entry.archivo}`).auth(token, { type: 'bearer' }).expect(200);
    }
  });
});
