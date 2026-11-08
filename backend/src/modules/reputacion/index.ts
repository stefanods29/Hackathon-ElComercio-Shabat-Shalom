/** Public interface of the Reputation module. Other modules may only import from here. */
export { ReputationModule } from './reputation.module.js';
export { REVIEW_CREATED_EVENT } from './domain/review.js';
export {
  REVIEW_PHOTO_READER,
  REVIEW_RISK_READER,
  type ReviewPhotoReader,
  type ReviewRiskReader,
} from './application/ports.js';
