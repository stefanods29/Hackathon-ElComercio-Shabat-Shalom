/**
 * Minimal contact lookup for other modules. Today only Notifications uses it, to send the SMS
 * backup of an urgent notice (Phase 2, Lot C). Phone numbers returned here must never be logged.
 */
export interface ContactDirectory {
  /** Phone of an existing user in E.164 format, or null when the user does not exist. */
  phoneOf(userId: string): Promise<string | null>;
}

export const CONTACT_DIRECTORY = Symbol('CONTACT_DIRECTORY');
