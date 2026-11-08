/**
 * Public interface of the Identity & Neighborhood module. Other modules may only import from
 * here (checked by `npm run boundaries`). Phase 0 owner: Lot B.
 */
export { IdentityModule } from './identity.module.js';
export {
  OPERATIONAL_IDENTITY,
  type OperationalIdentity,
  type OperationalAccount,
} from './application/operational-identity.js';
export type { RegisteredUser } from './application/ports.js';
export {
  REVIEWER_READER,
  type ReviewerContext,
  type ReviewerReader,
} from './application/reviewer-reader.js';
export { PRESENCE_CLEANUP_JOB } from './application/identity-events.js';
export { AUTHOR_TRUST, type AuthorTrust } from './application/author-trust.js';
/** Phase 2, Lot C: phone lookup for the SMS backup of urgent notices. */
export { IdentityContactsModule } from './identity-contacts.module.js';
export { CONTACT_DIRECTORY, type ContactDirectory } from './application/contact-directory.js';
