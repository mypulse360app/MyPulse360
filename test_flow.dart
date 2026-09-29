import 'package:supabase/supabase.dart';
void main() async {
  final client = SupabaseClient('https://arxrtodtnrmhwbecwyxm.supabase.co', 'sb_publishable_RLksAvPtIo1rAepq03Pavg_p80valSC');
  
  // We need to sign in as Pharmacist!
  final auth = await client.auth.signInWithPassword(email: 'sravin+ph@example.com', password: 'password123'); // wait, do I know a pharmacist email?
  print('Auth: \');
}
