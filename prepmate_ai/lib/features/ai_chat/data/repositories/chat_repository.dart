import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/chat_entity.dart';
import '../../../../core/constants/app_constants.dart';

/// AI service abstraction — swap provider by changing [AiProvider]
enum AiProvider { openAI, anthropic, gemini, custom }

abstract class AiService {
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String newMessage,
    String systemPrompt,
  });
}

/// OpenAI-compatible implementation (works with OpenAI, Together, Groq, etc.)
class OpenAiService implements AiService {
  final Dio _dio;
  final String _apiKey;
  final String _model;
  final String _baseUrl;

  OpenAiService({
    required String apiKey,
    String model = 'gpt-4o-mini',
    String baseUrl = 'https://prepmate-ay6b.onrender.com',
  })  : _apiKey = apiKey,
        _model = model,
        _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String newMessage,
    String systemPrompt = _kSystemPrompt,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.take(20).map((m) => m.toApiMessage()),
      {'role': 'user', 'content': newMessage},
    ];

    final response = await _dio.post(
      '/chat/completions',
      data: {
        'model': _model,
        'messages': messages,
        'max_tokens': 1024,
        'temperature': 0.7,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }

  static const _kSystemPrompt = '''
You are PrepMate AI, a knowledgeable and encouraging study tutor. 
Your role is to help students understand concepts, answer questions, 
explain topics clearly, and provide study guidance.
- Be concise but thorough
- Use examples to illustrate complex ideas
- Encourage the student when they struggle
- Format responses with markdown where helpful
''';
}

/// Chat Repository — stores sessions in Firestore
class ChatRepository {
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.chatsCollection);

  // Watch all sessions ordered by latest
  Stream<List<ChatSession>> watchSessions(String uid) => _sessions(uid)
      .orderBy('updatedAt', descending: true)
      .limit(AppConstants.chatHistoryLimit)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => ChatSession.fromMap(d.data(), d.id)).toList());

  // Get a single session
  Future<ChatSession?> getSession(String uid, String sessionId) async {
    final doc = await _sessions(uid).doc(sessionId).get();
    return doc.exists ? ChatSession.fromMap(doc.data()!, doc.id) : null;
  }

  // Create a new session
  Future<String> createSession(String uid, String firstMessage) async {
    final id = _uuid.v4();
    final title = firstMessage.length > 40
        ? '${firstMessage.substring(0, 40)}...'
        : firstMessage;
    await _sessions(uid).doc(id).set({
      'title': title,
      'messages': [],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  // Append a message to an existing session
  Future<void> appendMessage(
      String uid, String sessionId, ChatMessage message) async {
    await _sessions(uid).doc(sessionId).update({
      'messages': FieldValue.arrayUnion([message.toMap()]),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Delete a session
  Future<void> deleteSession(String uid, String sessionId) async {
    await _sessions(uid).doc(sessionId).delete();
  }
}
