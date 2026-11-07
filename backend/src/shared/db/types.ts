import type { ColumnType } from 'kysely';

/** `timestamptz`: read as `Date`; written as `Date` or ISO text. */
export type Timestamp = ColumnType<Date, Date | string, Date | string>;
export type NullableTimestamp = ColumnType<
  Date | null,
  Date | string | null | undefined,
  Date | string | null
>;
/** Column with a database default: optional on insert. */
export type WithDefault<T> = ColumnType<T, T | undefined, T>;
/** `jsonb`: written with `sql` (see `asJsonb`) so arrays are not mistaken for Postgres arrays. */
export type Jsonb<T = unknown> = ColumnType<T, unknown, unknown>;
