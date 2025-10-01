class AppMessages {
  AppMessages._();

  // General UI Messages
  static const String loading = 'Loading...';
  static const String pleaseLogin = 'Please log in to continue';
  static const String processingAuth = 'Processing authentication...';
  static const String checkAuthStatus = 'Check Auth Status';
  static const String pageNotFound = 'Page Not Found';
  static const String pageNotFoundDescription = 'The requested page could not be found.';
  static const String goHome = 'Go Home';
  static const String goBack = 'Go Back';
  static const String errorPrefix = 'Error: ';

  // Auth error messages
  static const String authFailedGeneric = 'Authentication failed. Please try again.';
  static const String networkError = 'Connection failed. Please check your internet connection and try again.';
  static const String sessionExpired = 'Your session has expired. Please sign in again.';
  static const String organizationNotAuthorized = 'Your organization is not authorized to use this application. Please contact your school administrator.';
  static const String accountDeactivated = 'Your account has been deactivated. Please contact your school administrator.';
  static const String profileCreationFailed = 'Profile creation failed. Please contact your administrator or try again.';
  static const String authTimeout = 'Sign-in timed out. Please check your connection and try again.';
  static const String accessDenied = 'Access denied. Please contact support.';

  // Route error messages
  static const String routeError = 'Failed to build the requested page. Please try again.';
  static const String parameterMissing = 'Required route parameter is missing.';

  // MARK: - Loading Messages
  static const String loadingPapers = 'Loading papers...';
  static const String loadingDetails = 'Loading details...';
  static const String loadingData = 'Loading data...';
  static const String processingRequest = 'Processing...';

  // MARK: - Success Messages
  static const String paperCreatedSuccess = 'Question paper created successfully!';
  static const String paperUpdatedSuccess = 'Question paper updated successfully!';
  static const String paperSubmittedSuccess = 'Paper submitted for review!';
  static const String paperApprovedSuccess = 'Paper approved successfully!';
  static const String paperRejectedSuccess = 'Paper rejected with feedback sent';
  static const String questionAddedSuccess = 'Question added';
  static const String questionUpdatedSuccess = 'Question updated';
  static const String questionRemovedSuccess = 'Question removed';
  static const String pdfGeneratedSuccess = 'PDF generated successfully';

  // MARK: - Error Messages
  static const String loadPapersFailed = 'Failed to load papers';
  static const String loadDetailsFailed = 'Failed to load details';
  static const String saveFailed = 'Failed to save';
  static const String submitFailed = 'Failed to submit paper';
  static const String approveFailed = 'Failed to approve paper';
  static const String rejectFailed = 'Failed to reject paper';
  static const String pdfGenerationFailed = 'Failed to generate PDF';
  static const String navigationFailed = 'Navigation failed. Please try again.';
  static const String refreshFailed = 'Refresh failed. Please try again.';

  // MARK: - Validation Messages
  static const String titleRequired = 'Please enter a paper title';
  static const String titleTooShort = 'Title must be at least 3 characters';
  static const String gradeRequired = 'Please select a grade level';
  static const String sectionRequired = 'Please select at least one section';
  static const String examTypeRequired = 'Please select an exam type';
  static const String subjectRequired = 'Please select at least one subject';
  static const String questionRequired = 'Please enter a question';
  static const String optionsRequired = 'Please provide at least 2 options';
  static const String blanksRequired = 'Add blanks using underscores (___) in your question';

  // MARK: - Empty State Messages
  static const String noPapersYet = 'No papers yet';
  static const String noPapersForReview = 'No papers to review';
  static const String noPapersThisMonth = 'No Papers This Month';
  static const String noPapersLastMonth = 'No Papers Last Month';
  static const String noArchivedPapers = 'No Archived Papers';
  static const String noPaperFound = 'Paper Not Found';

  // MARK: - Confirmation Messages
  static const String confirmSubmit = 'Are you sure you want to submit this paper for review?';
  static const String confirmDelete = 'Are you sure you want to delete this question?';
  static const String confirmLogout = 'Are you sure you want to sign out?';

  // MARK: - Info Messages
  static const String pullToRefresh = 'Pull down to refresh';
  static const String paperWillApplyAllSections = 'This paper will apply to all sections';
  static const String cannotEditSubmitted = 'You won\'t be able to edit it until it\'s reviewed';

}