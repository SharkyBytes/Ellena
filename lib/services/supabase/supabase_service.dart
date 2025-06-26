import 'base_service.dart';
import 'auth_service.dart';
import 'task_service.dart';
import 'team_service.dart';
import 'ticket_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Main service class that provides access to all Supabase services
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  
  // Base service for common functionality
  final BaseSupabaseService _baseService = BaseSupabaseService();
  
  // Individual service instances
  late final AuthService _authService;
  late final TaskService _taskService;
  late final TeamService _teamService;
  late final TicketService _ticketService;
  
  factory SupabaseService() {
    return _instance;
  }
  
  SupabaseService._internal() {
    _authService = AuthService();
    _taskService = TaskService();
    _teamService = TeamService();
    _ticketService = TicketService();
  }
  
  // Initialize all services
  Future<void> initialize() async {
    await _baseService.initialize();
  }
  
  // Check if services are initialized
  bool get isInitialized => _baseService.isInitialized;
  
  // Expose client for backward compatibility
  SupabaseClient get client => _baseService.client;
  
  // Getters for base functionality
  Future<Map<String, dynamic>?> getCurrentUserProfile({bool forceRefresh = false}) => 
      _baseService.getCurrentUserProfile(forceRefresh: forceRefresh);
  
  Future<bool> updateUserProfile(Map<String, dynamic> data) => 
      _baseService.updateUserProfile(data);
  
  Future<void> signOut() => _baseService.signOut();
  
  // Authentication methods
  String generateTeamId() => _authService.generateTeamId();
  
  Future<Map<String, dynamic>> createTeam({
    required String teamName,
    required String adminName,
    required String adminEmail,
    required String password,
  }) => _authService.createTeam(
    teamName: teamName,
    adminName: adminName,
    adminEmail: adminEmail,
    password: password,
  );
  
  Future<Map<String, dynamic>> joinTeam({
    required String teamId,
    required String fullName,
    required String email,
    required String password,
  }) => _authService.joinTeam(
    teamId: teamId,
    fullName: fullName,
    email: email,
    password: password,
  );
  
  Future<bool> teamExists(String teamId) => _authService.teamExists(teamId);
  
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String token,
    required String type,
    Map<String, dynamic> userData = const {},
  }) => _authService.verifyOTP(
    email: email,
    token: token,
    type: type,
    userData: userData,
  );
  
  Future<Map<String, dynamic>> resendVerificationEmail(String email) => 
      _authService.resendVerificationEmail(email);
  
  // Task methods
  Future<List<Map<String, dynamic>>> getTasks() => _taskService.getTasks();
  
  Stream<List<Map<String, dynamic>>> get tasksStream => _taskService.tasksStream;
  
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedToUserId,
  }) => _taskService.createTask(
    title: title,
    description: description,
    dueDate: dueDate,
    assignedToUserId: assignedToUserId,
  );
  
  Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required String status,
  }) => _taskService.updateTaskStatus(
    taskId: taskId,
    status: status,
  );
  
  Future<Map<String, dynamic>> updateTaskApproval({
    required String taskId,
    required String approvalStatus,
  }) => _taskService.updateTaskApproval(
    taskId: taskId,
    approvalStatus: approvalStatus,
  );
  
  Future<Map<String, dynamic>?> getTaskDetails(String taskId) => 
      _taskService.getTaskDetails(taskId);
  
  Future<Map<String, dynamic>> addTaskComment({
    required String taskId,
    required String content,
  }) => _taskService.addTaskComment(
    taskId: taskId,
    content: content,
  );
  
  // Ticket methods
  Future<List<Map<String, dynamic>>> getTickets() => _ticketService.getTickets();
  
  Stream<List<Map<String, dynamic>>> get ticketsStream => _ticketService.ticketsStream;
  
  Future<Map<String, dynamic>> createTicket({
    required String title,
    String? description,
    required String priority,
    required String category,
    String? assignedToUserId,
  }) => _ticketService.createTicket(
    title: title,
    description: description,
    priority: priority,
    category: category,
    assignedToUserId: assignedToUserId,
  );
  
  Future<Map<String, dynamic>> updateTicketStatus({
    required String ticketId,
    required String status,
  }) => _ticketService.updateTicketStatus(
    ticketId: ticketId,
    status: status,
  );
  
  Future<Map<String, dynamic>> updateTicketApproval({
    required String ticketId,
    required String approvalStatus,
  }) => _ticketService.updateTicketApproval(
    ticketId: ticketId,
    approvalStatus: approvalStatus,
  );
  
  Future<Map<String, dynamic>> updateTicketPriority({
    required String ticketId,
    required String priority,
  }) => _ticketService.updateTicketPriority(
    ticketId: ticketId,
    priority: priority,
  );
  
  Future<Map<String, dynamic>?> getTicketDetails(String ticketId) => 
      _ticketService.getTicketDetails(ticketId);
  
  Future<Map<String, dynamic>> addTicketComment({
    required String ticketId,
    required String content,
  }) => _ticketService.addTicketComment(
    ticketId: ticketId,
    content: content,
  );
  
  Future<Map<String, dynamic>> assignTicket({
    required String ticketId,
    required String userId,
  }) => _ticketService.assignTicket(
    ticketId: ticketId,
    userId: userId,
  );
  
  List<String> getTicketCategories() => _ticketService.getTicketCategories();
  
  // Team methods
  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) => 
      _teamService.getTeamMembers(teamId);
  
  Stream<List<Map<String, dynamic>>> get teamMembersStream => 
      _teamService.teamMembersStream;
  
  Future<Map<String, dynamic>?> getCurrentTeam() => _teamService.getCurrentTeam();
  
  Future<Map<String, dynamic>> updateTeam(Map<String, dynamic> data) => 
      _teamService.updateTeam(data);
  
  Future<Map<String, dynamic>> inviteMember(String email) => 
      _teamService.inviteMember(email);
  
  // Dispose resources
  void dispose() {
    _taskService.dispose();
    _teamService.dispose();
    _ticketService.dispose();
  }
} 