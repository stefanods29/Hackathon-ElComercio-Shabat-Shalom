/** Public interface of the Moderation module. Other modules may only import from here. */
export { ModerationModule } from './moderation.module.js';
export { IS_SUSPENDED } from './application/moderation-policy-registration.js';
export { IMAGE_MODERATION, type ImageModeration } from './application/ports.js';
export { PublicationPolicy, type IsSuspended } from '../../shared/moderation/publication-policy.js';
export { ImageModerationRegistry } from './application/image-moderation-registry.js';
export {
  CONTENT_APPROVED,
  CONTENT_HIDDEN,
  CONTENT_RESTORED,
} from '../../shared/moderation/content-moderation.js';
