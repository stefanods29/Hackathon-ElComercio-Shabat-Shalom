/**
 * Public interface of the Identity & Neighborhood module. Other modules may only import from
 * here (checked by `npm run boundaries`). Phase 0 owner: Lot B.
 */
export { IdentityModule } from './identity.module.js';
export type { RegisteredUser } from './application/ports.js';
