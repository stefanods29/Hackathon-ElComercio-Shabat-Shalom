export const CONSENT_PURPOSES = ['uso_del_servicio', 'confirmacion_por_presencia'] as const;
export type ConsentPurpose = (typeof CONSENT_PURPOSES)[number];

export const CONSENT_POLICIES = {
  uso_del_servicio: { version: 1, required: true },
  confirmacion_por_presencia: { version: 1, required: false },
} as const satisfies Record<ConsentPurpose, { version: number; required: boolean }>;
