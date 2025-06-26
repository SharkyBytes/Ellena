import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient _client;
  bool _isInitialized = false;
  
  factory SupabaseService() {
    return _instance;
  }
  
  SupabaseService._internal();
  
  bool get isInitialized => _isInitialized;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Try to load from .env file
      await dotenv.load().catchError((e) {
        debugPrint('Error loading .env file: $e');
        // If .env file is not found, we'll use hardcoded values below
      });
      
      // Get values from .env or use placeholder values for development
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://vcyzvymahcfmfjfzaebm.supabase.co';
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZjeXp2eW1haGNmbWZqZnphZWJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3NjE5NjcsImV4cCI6MjA2NTMzNzk2N30.sXv-IIbPrL1CZD0HRAPWPAP8Wk4ZhyT9aiWZW1Wp6w0';
      
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }
  
  SupabaseClient get client => _client;
  
  // Generate a random 6-character team ID
  String generateTeamId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Create a new team with the generated team ID
  Future<Map<String, dynamic>> createTeam({
    required String teamName,
    required String adminName,
    required String adminEmail,
    required String password,
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      // Step 1: Register the admin user
      final authResponse = await _client.auth.signUp(
        email: adminEmail,
        password: password,
      );
      
      if (authResponse.user == null) {
        throw Exception('Failed to create user');
      }
      
      final userId = authResponse.user!.id;
      
      // Step 2: Generate a unique team ID
      String teamId;
      bool isUnique = false;
      int attempts = 0;
      
      do {
        teamId = generateTeamId();
        attempts++;
        
        try {
          // Use raw SQL query to avoid RLS issues
          final response = await _client.rpc(
            'check_team_code_exists',
            params: {'code': teamId},
          );
          
          isUnique = response == false;
        } catch (e) {
          debugPrint('Error checking team code: $e');
          // If we can't check, assume it's unique after 3 attempts
          if (attempts >= 3) {
            isUnique = true;
          }
        }
      } while (!isUnique && attempts < 10);
      
      // Step 3: Create the team
      final teamInsertResponse = await _client.from('teams').insert({
        'name': teamName,
        'team_code': teamId,
        'created_by': userId,
        'admin_name': adminName,
        'admin_email': adminEmail,
      }).select();
      
      final teamResponse = teamInsertResponse.isNotEmpty ? teamInsertResponse.first : null;
      
      if (teamResponse == null) {
        throw Exception('Failed to create team');
      }
      
      // Step 4: Update user profile
      await _client.from('users').insert({
        'id': userId,
        'full_name': adminName,
        'email': adminEmail,
        'team_id': teamResponse['id'],
        'role': 'admin',
      });
      
      return {
        'success': true,
        'teamId': teamId,
        'teamData': teamResponse,
      };
    } catch (e) {
      debugPrint('Error creating team: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Join an existing team
  Future<Map<String, dynamic>> joinTeam({
    required String teamId,
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      // Step 1: Check if the team exists using direct SQL query
      final teamExistsResponse = await _client.rpc(
        'check_team_code_exists',
        params: {'code': teamId},
      );
      
      if (teamExistsResponse != true) {
        return {
          'success': false,
          'error': 'Team not found',
        };
      }
      
      // Get the team ID
      final teamResponse = await _client
          .from('teams')
          .select('id')
          .eq('team_code', teamId)
          .limit(1);
      
      if (teamResponse.isEmpty) {
        return {
          'success': false,
          'error': 'Team not found',
        };
      }
      
      final teamIdUuid = teamResponse[0]['id'];
      
      // Step 2: Register the user
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (authResponse.user == null) {
        throw Exception('Failed to create user');
      }
      
      final userId = authResponse.user!.id;
      
      // Step 3: Add user to the team
      await _client.from('users').insert({
        'id': userId,
        'full_name': fullName,
        'email': email,
        'team_id': teamIdUuid,
        'role': 'member',
      });
      
      return {
        'success': true,
        'teamId': teamId,
      };
    } catch (e) {
      debugPrint('Error joining team: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Check if a team ID exists
  Future<bool> teamExists(String teamId) async {
    try {
      if (!_isInitialized) return false;
      
      // Use the RPC function to avoid RLS issues
      final response = await _client.rpc(
        'check_team_code_exists',
        params: {'code': teamId},
      );
      
      return response == true;
    } catch (e) {
      debugPrint('Error checking team: $e');
      return false;
    }
  }
  
  // Get current user profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      if (!_isInitialized) return null;
      
      final user = _client.auth.currentUser;
      if (user == null) return null;
      
      final response = await _client
          .from('users')
          .select('*, teams(name, team_code)')
          .eq('id', user.id)
          .maybeSingle();
          
      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      if (!_isInitialized) return false;
      
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      await _client
          .from('users')
          .update(data)
          .eq('id', user.id);
          
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    if (!_isInitialized) return;
    await _client.auth.signOut();
  }
  
  // Verify OTP for email verification
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String token,
    required String type,
    Map<String, dynamic> userData = const {},
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      // Verify the OTP token first
      final response = await _client.auth.verifyOTP(
        token: token,
        type: OtpType.signup,
        email: email,
      );
      
      if (response.user == null) {
        return {
          'success': false,
          'error': 'Invalid verification code',
        };
      }
      
      // Wait a moment for the auth to fully process
      await Future.delayed(const Duration(milliseconds: 500));

      // Set the user's password if provided
      String? password = userData['password'] as String?;
      if (password != null && password.isNotEmpty) {
        try {
          // User is already signed in after OTP verification, 
          // so we can update their password
          await _client.auth.updateUser(
            UserAttributes(
              password: password,
            ),
          );
        } catch (e) {
          debugPrint('Error setting password: $e');
          // Continue even if password setting fails
        }
      }
      
      // Handle different verification types
      if (type == 'signup_create' && userData.isNotEmpty) {
        try {
          // Generate a unique team ID
          String teamId;
          bool isUnique = false;
          int attempts = 0;
          
          do {
            teamId = generateTeamId();
            attempts++;
            
            try {
              final checkResponse = await _client.rpc(
                'check_team_code_exists',
                params: {'code': teamId},
              );
              
              isUnique = checkResponse == false;
            } catch (e) {
              debugPrint('Error checking team code: $e');
              if (attempts >= 3) {
                isUnique = true;
              }
            }
          } while (!isUnique && attempts < 10);
          
          // Step 1: Create the team
          final teamInsertResponse = await _client.from('teams').insert({
            'name': userData['teamName'] ?? 'New Team',
            'team_code': teamId,
            'created_by': response.user!.id,
            'admin_name': userData['adminName'] ?? '',
            'admin_email': email,
          }).select();
          
          final teamResponse = teamInsertResponse.isNotEmpty ? teamInsertResponse.first : null;
          
          if (teamResponse == null) {
            throw Exception('Failed to create team');
          }
          
          // Step 2: Create user profile with proper role
          await _client.from('users').insert({
            'id': response.user!.id,
            'full_name': userData['adminName'] ?? '',
            'email': email,
            'team_id': teamResponse['id'],
            'role': 'admin',
          });
          
          return {
            'success': true,
            'teamId': teamId,
          };
        } catch (e) {
          debugPrint('Error creating team after verification: $e');
          return {
            'success': false,
            'error': e.toString(),
          };
        }
      } else if (type == 'signup_join' && userData.isNotEmpty) {
        try {
          // Get the team ID
          final teamResponse = await _client
              .from('teams')
              .select('id')
              .eq('team_code', userData['teamId'])
              .limit(1);
          
          if (teamResponse.isEmpty) {
            return {
              'success': false,
              'error': 'Team not found',
            };
          }
          
          final teamIdUuid = teamResponse[0]['id'];
          
          // Create user profile with proper role
          await _client.from('users').insert({
            'id': response.user!.id,
            'full_name': userData['fullName'] ?? '',
            'email': email,
            'team_id': teamIdUuid,
            'role': 'member',
          });
          
          return {
            'success': true,
          };
        } catch (e) {
          debugPrint('Error joining team after verification: $e');
          return {
            'success': false,
            'error': e.toString(),
          };
        }
      }
      
      // Default success response
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Resend verification email
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      await _client.auth.resend(
        type: OtpType.email,
        email: email,
      );
      
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error resending verification email: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Get all members of a specific team
  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    try {
      if (!_isInitialized) return [];
      
      final user = _client.auth.currentUser;
      if (user == null) return [];
      
      // First, get the UUID of the team from the team code
      final teamResponse = await _client
          .from('teams')
          .select('id')
          .eq('team_code', teamId)
          .limit(1);
      
      if (teamResponse.isEmpty) return [];
      
      final teamIdUuid = teamResponse[0]['id'];
      
      // Then get all users in that team
      final response = await _client
          .from('users')
          .select('*')
          .eq('team_id', teamIdUuid)
          .order('role', ascending: false); // Put admins first
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting team members: $e');
      return [];
    }
  }
  
  // Task-related methods
  
  // Get tasks for the current user's team
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      if (!_isInitialized) return [];
      
      final user = _client.auth.currentUser;
      if (user == null) return [];
      
      // Get the user's team ID
      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) return [];
      
      final teamId = userProfile['team_id'];
      
      // Get all tasks for this team
      final response = await _client
          .from('tasks')
          .select('*')
          .eq('team_id', teamId)
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }
  
  // Create a new task
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedToUserId,
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Get the user's team ID
      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) {
        return {
          'success': false,
          'error': 'User not associated with a team',
        };
      }
      
      final teamId = userProfile['team_id'];
      
      // Create the task
      final Map<String, dynamic> taskData = {
        'title': title,
        'description': description,
        'status': 'todo',
        'approval_status': 'pending',
        'team_id': teamId,
        'created_by': user.id,
      };
      
      if (assignedToUserId != null && assignedToUserId.isNotEmpty) {
        taskData['assigned_to'] = assignedToUserId;
      }
      
      if (dueDate != null) {
        taskData['due_date'] = dueDate.toIso8601String();
      }
      
      final response = await _client
          .from('tasks')
          .insert(taskData)
          .select();
          
      if (response.isEmpty) {
        return {
          'success': false,
          'error': 'Failed to create task',
        };
      }
      
      return {
        'success': true,
        'task': response[0],
      };
    } catch (e) {
      debugPrint('Error creating task: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update a task's status
  Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Update the task status
      await _client
          .from('tasks')
          .update({'status': status})
          .eq('id', taskId);
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating task status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update a task's approval status (admin only)
  Future<Map<String, dynamic>> updateTaskApproval({
    required String taskId,
    required String approvalStatus,
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Check if user is admin
      final userProfile = await getCurrentUserProfile();
      if (userProfile == null || userProfile['role'] != 'admin') {
        return {
          'success': false,
          'error': 'Only admins can approve tasks',
        };
      }
      
      // Update the task approval status
      await _client
          .from('tasks')
          .update({'approval_status': approvalStatus})
          .eq('id', taskId);
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating task approval: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Get task details with comments
  Future<Map<String, dynamic>?> getTaskDetails(String taskId) async {
    try {
      if (!_isInitialized) return null;
      
      final user = _client.auth.currentUser;
      if (user == null) return null;
      
      // Get task details
      final taskResponse = await _client
          .from('tasks')
          .select('*')
          .eq('id', taskId)
          .single();
      
      // Get task comments
      final commentsResponse = await _client
          .from('task_comments')
          .select('*')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
          
      // Get creator and assignee info
      String? createdById = taskResponse['created_by'];
      String? assignedToId = taskResponse['assigned_to'];
      
      Map<String, dynamic>? creator;
      Map<String, dynamic>? assignee;
      
      if (createdById != null) {
        final creatorResponse = await _client
            .from('users')
            .select('id, full_name')
            .eq('id', createdById)
            .maybeSingle();
        
        if (creatorResponse != null) {
          creator = creatorResponse;
        }
      }
      
      if (assignedToId != null) {
        final assigneeResponse = await _client
            .from('users')
            .select('id, full_name')
            .eq('id', assignedToId)
            .maybeSingle();
        
        if (assigneeResponse != null) {
          assignee = assigneeResponse;
        }
      }
      
      // Get comment user info
      List<Map<String, dynamic>> commentsWithUsers = [];
      for (var comment in commentsResponse) {
        String? userId = comment['user_id'];
        Map<String, dynamic>? user;
        
        if (userId != null) {
          final userResponse = await _client
              .from('users')
              .select('id, full_name')
              .eq('id', userId)
              .maybeSingle();
          
          if (userResponse != null) {
            user = userResponse;
          }
        }
        
        commentsWithUsers.add({
          ...comment,
          'user': user,
        });
      }
      
      Map<String, dynamic> taskWithDetails = {
        ...taskResponse,
        'creator': creator,
        'assignee': assignee,
      };
          
      return {
        'task': taskWithDetails,
        'comments': commentsWithUsers,
      };
    } catch (e) {
      debugPrint('Error getting task details: $e');
      return null;
    }
  }
  
  // Add a comment to a task
  Future<Map<String, dynamic>> addTaskComment({
    required String taskId,
    required String content,
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Add the comment
      final response = await _client
          .from('task_comments')
          .insert({
            'task_id': taskId,
            'user_id': user.id,
            'content': content,
          })
          .select();
          
      if (response.isEmpty) {
        return {
          'success': false,
          'error': 'Failed to add comment',
        };
      }
      
      // Get user info
      final userResponse = await _client
          .from('users')
          .select('id, full_name')
          .eq('id', user.id)
          .maybeSingle();
      
      final commentWithUser = {
        ...response[0],
        'user': userResponse,
      };
          
      return {
        'success': true,
        'comment': commentWithUser,
      };
    } catch (e) {
      debugPrint('Error adding task comment: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
} 