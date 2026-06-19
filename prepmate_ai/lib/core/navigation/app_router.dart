import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/pdf_library/presentation/screens/pdf_library_screen.dart';
import '../../features/pdf_library/presentation/screens/pdf_viewer_screen.dart';
import '../../features/pdf_library/presentation/screens/pdf_upload_screen.dart';
import '../../features/ai_chat/presentation/screens/chat_screen.dart';
import '../../features/ai_chat/presentation/screens/chat_history_screen.dart';
import '../../features/mcq/presentation/screens/mcq_topic_screen.dart';
import '../../features/mcq/presentation/screens/mcq_question_screen.dart';
import '../../features/mcq/presentation/screens/mcq_result_screen.dart';
import '../../features/planner/presentation/screens/planner_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../widgets/main_scaffold.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String pdfLibrary = '/pdf-library';
  static const String pdfViewer = '/pdf-viewer';
  static const String pdfUpload = '/pdf-upload';
  static const String aiChat = '/ai-chat';
  static const String chatHistory = '/chat-history';
  static const String mcqTopic = '/mcq-topic';
  static const String mcqQuestion = '/mcq-question';
  static const String mcqResult = '/mcq-result';
  static const String planner = '/planner';
  static const String profile = '/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.whenOrNull(
        data: (user) => user != null,
      ) ?? false;

      final isAuthRoute = [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
      ].contains(state.matchedLocation);

      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const SignupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ForgotPasswordScreen(),
        ),
      ),

      // Main Shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => _fadeTransition(
              state,
              const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.pdfLibrary,
            name: 'pdfLibrary',
            pageBuilder: (context, state) => _fadeTransition(
              state,
              const PdfLibraryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.aiChat,
            name: 'aiChat',
            pageBuilder: (context, state) => _fadeTransition(
              state,
              const ChatScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.mcqTopic,
            name: 'mcqTopic',
            pageBuilder: (context, state) => _fadeTransition(
              state,
              const McqTopicScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.planner,
            name: 'planner',
            pageBuilder: (context, state) => _fadeTransition(
              state,
              const PlannerScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) => _fadeTransition(
              state,
              const ProfileScreen(),
            ),
          ),
        ],
      ),

      // Detail routes (full screen, no shell)
      GoRoute(
        path: AppRoutes.pdfViewer,
        name: 'pdfViewer',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return _slideTransition(
            state,
            PdfViewerScreen(
              pdfId: extra['pdfId'] as String,
              pdfName: extra['pdfName'] as String,
              pdfUrl: extra['pdfUrl'] as String,
              lastPage: extra['lastPage'] as int? ?? 0,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.pdfUpload,
        name: 'pdfUpload',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const PdfUploadScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.chatHistory,
        name: 'chatHistory',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ChatHistoryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.mcqQuestion,
        name: 'mcqQuestion',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return _slideTransition(
            state,
            McqQuestionScreen(
              topic: extra['topic'] as String,
              difficulty: extra['difficulty'] as String,
              questionCount: extra['questionCount'] as int,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.mcqResult,
        name: 'mcqResult',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return _slideTransition(
            state,
            McqResultScreen(
              topic: extra['topic'] as String,
              score: extra['score'] as int,
              total: extra['total'] as int,
              questions: extra['questions'] as List<dynamic>,
            ),
          );
        },
      ),
    ],
  );
});

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}

CustomTransitionPage<void> _slideTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOut));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}
