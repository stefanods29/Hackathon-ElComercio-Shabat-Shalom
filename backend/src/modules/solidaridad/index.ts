/**
 * Public interface of the Solidarity module (favor wall). Other modules only import from here.
 * Phase 0 reference implementation; Lot B completes it.
 */
export { SolidarityModule } from './solidarity.module.js';
export { FAVOR_TAKEN_EVENT, POST_CREATED_EVENT, POST_TYPES, type PostType } from './domain/post.js';
