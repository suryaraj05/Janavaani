import '../../models/grievance.dart';

/// Feed algorithm for sorting grievances based on multiple factors
/// 
/// Factors considered:
/// 1. Upvotes (higher = better)
/// 2. Priority (urgent > high > medium > low)
/// 3. Status (active issues prioritized over resolved)
/// 4. Recency (recent issues get slight boost)
/// 5. Engagement (issues with more upvotes and recent activity rank higher)
class FeedAlgorithm {
  /// Sort grievances for citizen feed
  /// Prioritizes: upvotes, priority, recency, active status
  static List<Grievance> sortForCitizens(List<Grievance> grievances) {
    final sorted = List<Grievance>.from(grievances);
    
    sorted.sort((a, b) {
      // Calculate score for each grievance
      final scoreA = _calculateCitizenScore(a);
      final scoreB = _calculateCitizenScore(b);
      
      // Higher score = higher in feed
      return scoreB.compareTo(scoreA);
    });
    
    return sorted;
  }
  
  /// Sort grievances for admin/department feed
  /// Prioritizes: upvotes, priority, reported date, active status
  static List<Grievance> sortForAdminDepartment(List<Grievance> grievances) {
    final sorted = List<Grievance>.from(grievances);
    
    sorted.sort((a, b) {
      // Calculate score for each grievance
      final scoreA = _calculateAdminDepartmentScore(a);
      final scoreB = _calculateAdminDepartmentScore(b);
      
      // Higher score = higher in feed
      return scoreB.compareTo(scoreA);
    });
    
    return sorted;
  }
  
  /// Calculate score for citizen feed
  static double _calculateCitizenScore(Grievance grievance) {
    double score = 0.0;
    
    // 1. Upvotes (40% weight) - logarithmic scale to prevent domination
    final upvoteScore = (grievance.upvotes * 10) + (grievance.upvotedBy.length * 10);
    score += upvoteScore * 0.4;
    
    // 2. Priority (30% weight)
    final priorityScore = _getPriorityScore(grievance.priority);
    score += priorityScore * 0.3;
    
    // 3. Recency (20% weight) - more recent = higher score
    final now = DateTime.now();
    final daysSinceCreation = now.difference(grievance.createdAt).inDays;
    final recencyScore = (30 - daysSinceCreation).clamp(0, 30).toDouble();
    score += recencyScore * 0.2;
    
    // 4. Status (10% weight) - active issues prioritized
    final statusScore = _getStatusScore(grievance.status);
    score += statusScore * 0.1;
    
    return score;
  }
  
  /// Calculate score for admin/department feed
  static double _calculateAdminDepartmentScore(Grievance grievance) {
    double score = 0.0;
    
    // 1. Upvotes (35% weight) - shows citizen concern
    final upvoteScore = (grievance.upvotes * 10) + (grievance.upvotedBy.length * 10);
    score += upvoteScore * 0.35;
    
    // 2. Priority (35% weight) - urgent issues must be addressed
    final priorityScore = _getPriorityScore(grievance.priority);
    score += priorityScore * 0.35;
    
    // 3. Reported date (20% weight) - older unresolved issues need attention
    final now = DateTime.now();
    final daysSinceCreation = now.difference(grievance.createdAt).inDays;
    // For active issues, older = higher priority (needs attention)
    // For resolved issues, newer = higher priority (recently resolved)
    final dateScore = _isActiveStatus(grievance.status)
        ? daysSinceCreation.clamp(0, 90).toDouble() // Older active issues need attention
        : (30 - daysSinceCreation).clamp(0, 30).toDouble(); // Recent resolved issues
    score += dateScore * 0.2;
    
    // 4. Status (10% weight) - active issues prioritized
    final statusScore = _getStatusScore(grievance.status);
    score += statusScore * 0.1;
    
    return score;
  }
  
  /// Get priority score (higher = more urgent)
  static double _getPriorityScore(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 100.0;
      case 'high':
        return 75.0;
      case 'medium':
        return 50.0;
      case 'low':
        return 25.0;
      default:
        return 50.0;
    }
  }
  
  /// Get status score (active issues get higher score)
  static double _getStatusScore(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
      case 'assigned':
        return 100.0; // New issues need attention
      case 'in_progress':
        return 80.0; // Being worked on
      case 'resolved':
        return 40.0; // Resolved but still relevant
      case 'closed':
        return 20.0; // Closed, less relevant
      case 'rejected':
        return 10.0; // Rejected, least relevant
      default:
        return 50.0;
    }
  }
  
  /// Check if status is active (not resolved/closed/rejected)
  static bool _isActiveStatus(String status) {
    final activeStatuses = ['submitted', 'assigned', 'in_progress'];
    return activeStatuses.contains(status.toLowerCase());
  }
}

