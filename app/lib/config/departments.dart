// DEPRECATED: Use ConfigService instead
// These are fallback values only
// Always fetch from backend using ConfigService.getDepartments()

/// Fallback departments (use ConfigService for dynamic values)
const List<String> fallbackDepartments = [
  'Municipal Cleanliness',
  'Electrical Department',
  'Water Department',
  'Roads & Infrastructure',
  'Health & Sanitation',
];

/// Fallback priorities (use ConfigService for dynamic values)
const List<String> fallbackPriorities = [
  'low',
  'medium',
  'high',
  'urgent',
];

/// Fallback statuses (use ConfigService for dynamic values)
const List<String> fallbackStatuses = [
  'submitted',
  'assigned',
  'in_progress',
  'resolved',
  'closed',
  'rejected',
];

// For backward compatibility (deprecated - use ConfigService)
@Deprecated('Use ConfigService.getDepartments() instead')
const List<String> departments = fallbackDepartments;

@Deprecated('Use ConfigService.getPriorities() instead')
const List<String> priorities = fallbackPriorities;

@Deprecated('Use ConfigService.getStatuses() instead')
const List<String> statuses = fallbackStatuses;

