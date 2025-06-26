import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_service.dart';

class AuthService {
  final BaseSupabaseService _baseService = BaseSupabaseService();
  
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
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      // Step 1: Register the admin user
      final authResponse = await _baseService.client.auth.signUp(
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
          final response = await _baseService.client.rpc(
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
      final teamInsertResponse = await _baseService.client.from('teams').insert({
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
      await _baseService.client.from('users').insert({
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
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      // Step 1: Check if the team exists using direct SQL query
      final teamExistsResponse = await _baseService.client.rpc(
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
      final teamResponse = await _baseService.client
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
      final authResponse = await _baseService.client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (authResponse.user == null) {
        throw Exception('Failed to create user');
      }
      
      final userId = authResponse.user!.id;
      
      // Step 3: Add user to the team
      await _baseService.client.from('users').insert({
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
      if (!_baseService.isInitialized) return false;
      
      // Use the RPC function to avoid RLS issues
      final response = await _baseService.client.rpc(
        'check_team_code_exists',
        params: {'code': teamId},
      );
      
      return response == true;
    } catch (e) {
      debugPrint('Error checking team: $e');
      return false;
    }
  }
  
  // Verify OTP for email verification
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String token,
    required String type,
    Map<String, dynamic> userData = const {},
  }) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      // Verify the OTP token first
      final response = await _baseService.client.auth.verifyOTP(
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
          await _baseService.client.auth.updateUser(
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
              final checkResponse = await _baseService.client.rpc(
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
          final teamInsertResponse = await _baseService.client.from('teams').insert({
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
          await _baseService.client.from('users').insert({
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
          final teamResponse = await _baseService.client
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
          await _baseService.client.from('users').insert({
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
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      await _baseService.client.auth.resend(
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
} 