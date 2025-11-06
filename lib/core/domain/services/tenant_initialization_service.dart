/// Service for checking and caching tenant initialization status
///
/// This service provides a centralized way to check if a tenant has been initialized
/// through the admin setup wizard. It includes:
/// - Caching to avoid repeated database queries
/// - Proper error handling and logging
/// - Clear separation of concerns
///
/// The tenant initialization status is checked during authentication to determine
/// if a user should be redirected to the setup wizard or allowed to proceed.
abstract class TenantInitializationService {
  /// Check if a tenant has been initialized (admin setup wizard completed)
  ///
  /// Args:
  ///   tenantId: The UUID of the tenant to check
  ///
  /// Returns:
  ///   true if tenant.is_initialized = true, false otherwise
  ///
  /// Note:
  ///   - Results are cached for the lifetime of the service instance
  ///   - On query error, returns false (safe default - user can retry)
  ///   - Logs all errors for debugging
  Future<bool> isTenantInitialized(String tenantId);

  /// Clear the initialization cache (useful for testing or after setup)
  void clearCache();

  /// Clear cache for a specific tenant
  void clearCacheForTenant(String tenantId);
}
