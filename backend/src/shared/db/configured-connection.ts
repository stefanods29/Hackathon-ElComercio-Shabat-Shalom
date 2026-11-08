import { Connector, IpAddressTypes } from '@google-cloud/cloud-sql-connector';
import type { AppConfig } from '../config/app-config.js';
import { createKysely } from './connection.js';

export const DATABASE_CONNECTION = Symbol('DATABASE_CONNECTION');
/** Cloud SQL uses the official TLS connector with workload credentials; local PostgreSQL stays unchanged. */
export async function connectDatabase(config: AppConfig, maxConnections = 10) {
  const connector = config.CLOUD_SQL_INSTANCE ? new Connector() : undefined;
  try {
    const options = connector
      ? await connector.getOptions({
          instanceConnectionName: config.CLOUD_SQL_INSTANCE!,
          ipType: IpAddressTypes.PRIVATE,
        })
      : {};
    const db = createKysely(config.DATABASE_URL, maxConnections, options);
    return {
      db,
      close: async () => {
        try {
          await db.destroy();
        } finally {
          connector?.close();
        }
      },
    };
  } catch {
    connector?.close();
    throw new Error('No se pudo preparar la conexión segura a la base de datos');
  }
}
export type DatabaseConnection = Awaited<ReturnType<typeof connectDatabase>>;
