import { z } from 'zod';

export const CATEGORIES = [
  'roads',
  'water',
  'education',
  'health',
  'electricity',
  'sanitation',
  'transport',
  'agriculture',
  'welfare',
  'other',
] as const;

export const SUBCATEGORIES: Record<(typeof CATEGORIES)[number], readonly string[]> = {
  roads: ['new_road', 'repair', 'bridge_culvert', 'streetlights'],
  water: ['drinking_water', 'irrigation', 'drainage'],
  education: ['school_upgrade', 'new_school', 'school_infrastructure', 'vocational_training'],
  health: ['phc_upgrade', 'new_facility', 'staffing_equipment'],
  electricity: ['new_connection', 'reliability'],
  sanitation: ['toilets', 'waste_management'],
  transport: ['bus_service', 'rail'],
  agriculture: ['market_access', 'storage', 'subsidy_access'],
  welfare: ['pension_schemes', 'housing', 'ration'],
  other: ['other'],
};

export const CategorySchema = z.enum(CATEGORIES);
export const KindSchema = z.enum(['development_request', 'grievance', 'question', 'other']);
export const UrgencySchema = z.enum(['safety_critical', 'high', 'medium', 'low']);
export const SourceSchema = z.enum([
  'app',
  'whatsapp',
  'meeting',
  'youtube',
  'portal_mock',
  'meta_mock',
]);
export const ModalitySchema = z.enum(['text', 'voice', 'photo_text', 'video_comment', 'letter']);
export const AuthKindSchema = z.enum([
  'firebase_uid',
  'whatsapp_phone',
  'youtube_channel',
  'anonymous',
]);
export const GeocodeMethodSchema = z.enum([
  'device_gps',
  'exif',
  'nominatim_biased',
  'google_geocode_fallback',
  'staff_pin',
  'none',
]);
export const GeocodeConfidenceSchema = z.enum(['high', 'medium', 'low', 'none']);
export const ClusterDecisionSchema = z.enum(['auto', 'staff_review', 'staff_repair']);
export const LifecycleStatusSchema = z.enum([
  'acknowledged',
  'under_review',
  'recommended',
  'taken_up',
  'completed',
]);
export const UserRoleSchema = z.enum(['citizen', 'mp_staff', 'mp']);
export const DisplayLocaleSchema = z.enum(['te', 'hi', 'en']);

export type Category = z.infer<typeof CategorySchema>;
export type Source = z.infer<typeof SourceSchema>;
