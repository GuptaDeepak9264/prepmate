class AppConstants {
  // App Info
  static const String appName = 'PrepMate AI';
  static const String appVersion = '1.0.0';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String pdfsCollection = 'pdfs';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String mcqSessionsCollection = 'mcq_sessions';
  static const String tasksCollection = 'tasks';
  static const String streaksCollection = 'streaks';

  // Storage Paths
  static const String pdfStoragePath = 'pdfs';
  static const String avatarStoragePath = 'avatars';

  // SharedPreferences Keys
  static const String themeKey = 'app_theme';
  static const String onboardingKey = 'onboarding_done';
  static const String lastReadPagesKey = 'last_read_pages';

  // PDF Categories
  static const List<String> pdfCategories = [
    'All',
    'Mathematics',
    'Science',
    'History',
    'Language',
    'General',
  ];

  // MCQ Difficulties
  static const List<String> mcqDifficulties = [
    'Easy',
    'Medium',
    'Hard',
  ];

  // Limits
  static const int maxFileSizeMB = 50;
  static const int chatHistoryLimit = 50;
  static const int streakGoalDays = 7;
}

class AppStrings {
  // Auth
  static const String welcomeBack = 'Welcome back';
  static const String signInToContinue = 'Sign in to continue your journey';
  static const String createAccount = 'Create your account';
  static const String joinPrepMate = 'Join PrepMate AI today';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String emailLabel = 'Email address';
  static const String passwordLabel = 'Password';
  static const String nameLabel = 'Full name';
  static const String loginButton = 'Sign In';
  static const String signupButton = 'Create Account';
  static const String googleButton = 'Continue with Google';
  static const String noAccount = "Don't have an account?";
  static const String hasAccount = 'Already have an account?';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';

  // Dashboard
  static const String goodMorning = 'Good morning';
  static const String goodAfternoon = 'Good afternoon';
  static const String goodEvening = 'Good evening';
  static const String studyStreak = 'Study Streak';
  static const String todaysTasks = "Today's Tasks";
  static const String weeklyProgress = 'Weekly Progress';
  static const String quickActions = 'Quick Actions';

  // PDF Library
  static const String pdfLibrary = 'PDF Library';
  static const String uploadPDF = 'Upload PDF';
  static const String searchPDFs = 'Search PDFs...';
  static const String noPDFs = 'No PDFs yet';
  static const String noPDFsSubtitle = 'Upload your first study material';

  // AI Chat
  static const String aiChat = 'AI Tutor';
  static const String messageHint = 'Ask anything...';
  static const String newChat = 'New Chat';

  // MCQ
  static const String mcqModule = 'MCQ Practice';
  static const String enterTopic = 'Enter a topic';
  static const String generateMCQ = 'Generate Questions';
  static const String submitAnswer = 'Submit Answer';
  static const String nextQuestion = 'Next Question';
  static const String viewResults = 'View Results';
  static const String tryAgain = 'Try Again';

  // Planner
  static const String dailyPlanner = 'Daily Planner';
  static const String addTask = 'Add Task';
  static const String noTasks = 'No tasks for today';
  static const String noTasksSubtitle = 'Add your first task to stay organized';

  // Profile
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String logout = 'Sign Out';
  static const String logoutConfirm = 'Are you sure you want to sign out?';
}
