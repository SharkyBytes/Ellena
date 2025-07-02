import 'package:flutter/material.dart';
import 'base_service.dart';
import 'dart:async';

class MeetingService {
  final BaseSupabaseService _baseService = BaseSupabaseService();
  
  // Stream controller for meeting updates
  final StreamController<List<Map<String, dynamic>>> _meetingsStreamController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Expose stream for UI components to listen to
  Stream<List<Map<String, dynamic>>> get meetingsStream => _meetingsStreamController.stream;
  
  // Get meetings for the current user's team
  Future<List<Map<String, dynamic>>> getMeetings() async {
    try {
      if (!_baseService.isInitialized) return [];
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return [];
      
      // Get the user's team ID
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) return [];
      
      final teamId = userProfile['team_id'];
      
      // Get all meetings for this team
      final response = await _baseService.client
          .from('meetings')
          .select('*')
          .eq('team_id', teamId)
          .order('meeting_date', ascending: true);
      
      final meetings = List<Map<String, dynamic>>.from(response);
      
      // Fetch creator information for each meeting
      final meetingsWithDetails = await _addUserDetailsToMeetings(meetings);
      
      // Update the stream
      _meetingsStreamController.add(meetingsWithDetails);
      
      return meetingsWithDetails;
    } catch (e) {
      debugPrint('Error getting meetings: $e');
      return [];
    }
  }
  
  // Create a new meeting
  Future<Map<String, dynamic>> createMeeting({
    required String title,
    String? description,
    required DateTime meetingDate,
    String? meetingUrl,
    String? transcription,
    String? aiSummary,
  }) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Get the user's team ID
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) {
        return {
          'success': false,
          'error': 'User not associated with a team',
        };
      }
      
      final teamId = userProfile['team_id'];
      
      // Create the meeting data map
      final Map<String, dynamic> meetingData = {
        'title': title,
        'description': description,
        'meeting_date': meetingDate.toIso8601String(),
        'meeting_url': meetingUrl,
        'team_id': teamId,
        'created_by': user.id,
        'transcription': transcription,
        'ai_summary': aiSummary,
      };
      
      final response = await _baseService.client
          .from('meetings')
          .insert(meetingData)
          .select();
          
      if (response.isEmpty) {
        return {
          'success': false,
          'error': 'Failed to create meeting',
        };
      }
      
      // Refresh meetings list
      getMeetings();
      
      return {
        'success': true,
        'meeting': response[0],
      };
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Get meeting details
  Future<Map<String, dynamic>?> getMeetingDetails(String meetingId) async {
    try {
      if (!_baseService.isInitialized) return null;
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return null;
      
      // Get meeting details
      final meetingResponse = await _baseService.client
          .from('meetings')
          .select('*')
          .eq('id', meetingId)
          .single();
      
      // Get creator info
      String? createdById = meetingResponse['created_by'];
      Map<String, dynamic>? creator;
      
      if (createdById != null) {
        final creatorResponse = await _baseService.client
            .from('users')
            .select('id, full_name, role')
            .eq('id', createdById)
            .maybeSingle();
        
        if (creatorResponse != null) {
          creator = creatorResponse;
        }
      }
      
      Map<String, dynamic> meetingWithDetails = {
        ...meetingResponse,
        'creator': creator,
      };
          
      return meetingWithDetails;
    } catch (e) {
      debugPrint('Error getting meeting details: $e');
      return null;
    }
  }
  
  // Delete a meeting (admin or creator only)
  Future<Map<String, dynamic>> deleteMeeting(String meetingId) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Delete the meeting
      await _baseService.client
          .from('meetings')
          .delete()
          .eq('id', meetingId);
      
      // Refresh meetings list
      getMeetings();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error deleting meeting: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update meeting details
  Future<Map<String, dynamic>> updateMeeting({
    required String meetingId,
    String? title,
    String? description,
    DateTime? meetingDate,
    String? meetingUrl,
    String? transcription,
    String? aiSummary,
  }) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Create update data map with only the fields that need to be updated
      final Map<String, dynamic> updateData = {};
      
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (meetingDate != null) updateData['meeting_date'] = meetingDate.toIso8601String();
      if (meetingUrl != null) updateData['meeting_url'] = meetingUrl;
      if (transcription != null) updateData['transcription'] = transcription;
      if (aiSummary != null) updateData['ai_summary'] = aiSummary;
      
      // Update the meeting
      await _baseService.client
          .from('meetings')
          .update(updateData)
          .eq('id', meetingId);
      
      // Refresh meetings list
      getMeetings();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating meeting: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update meeting transcription
  Future<Map<String, dynamic>> updateTranscription({
    required String meetingId,
    required String transcription,
  }) async {
    return updateMeeting(
      meetingId: meetingId,
      transcription: transcription,
    );
  }
  
  // Update meeting AI summary
  Future<Map<String, dynamic>> updateAISummary({
    required String meetingId,
    required String aiSummary,
  }) async {
    return updateMeeting(
      meetingId: meetingId,
      aiSummary: aiSummary,
    );
  }
  
  // Helper method to add user details to meetings
  Future<List<Map<String, dynamic>>> _addUserDetailsToMeetings(List<Map<String, dynamic>> meetings) async {
    // Create a map to cache user details
    final Map<String, Map<String, dynamic>> userCache = {};
    
    // Function to get user details with caching
    Future<Map<String, dynamic>?> getUserDetails(String? userId) async {
      if (userId == null) return null;
      
      // Return from cache if available
      if (userCache.containsKey(userId)) {
        return userCache[userId];
      }
      
      // Fetch from database
      final userResponse = await _baseService.client
          .from('users')
          .select('id, full_name, role')
          .eq('id', userId)
          .maybeSingle();
      
      // Cache the result
      if (userResponse != null) {
        userCache[userId] = userResponse;
      }
      
      return userResponse;
    }
    
    // Process all meetings
    List<Map<String, dynamic>> result = [];
    
    for (var meeting in meetings) {
      final createdById = meeting['created_by'];
      final creator = await getUserDetails(createdById);
      
      result.add({
        ...meeting,
        'creator': creator,
      });
    }
    
    return result;
  }
  
  // Get upcoming meetings (meetings with date in the future)
  Future<List<Map<String, dynamic>>> getUpcomingMeetings() async {
    final allMeetings = await getMeetings();
    final now = DateTime.now();
    
    return allMeetings.where((meeting) {
      final meetingDate = DateTime.parse(meeting['meeting_date']);
      return meetingDate.isAfter(now);
    }).toList();
  }
  
  // Get past meetings (meetings with date in the past)
  Future<List<Map<String, dynamic>>> getPastMeetings() async {
    final allMeetings = await getMeetings();
    final now = DateTime.now();
    
    return allMeetings.where((meeting) {
      final meetingDate = DateTime.parse(meeting['meeting_date']);
      return meetingDate.isBefore(now);
    }).toList();
  }
  
  // Dispose resources
  void dispose() {
    _meetingsStreamController.close();
  }
} 