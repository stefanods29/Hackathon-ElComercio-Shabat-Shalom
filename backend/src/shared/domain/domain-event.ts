/**
 * A domain fact other modules may need to know about.
 * It is stored in the outbox in the SAME transaction as the change that produced it.
 */
export interface DomainEvent<TPayload extends object = Record<string, unknown>> {
  /** `<modulo>.<fact_in_past_tense>`, e.g. `solidaridad.favor_taken`. */
  readonly type: string;
  readonly aggregateId: string;
  readonly occurredAt: Date;
  readonly payload: TPayload;
}
