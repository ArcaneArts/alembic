import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';

class GitHubOAuth {
  static const String clientId = 'Iv23li7H08gj1niscAof';
  static const String clientSecret = 'bee79f9f1c7f186fd008311af2d12f730bd34490';
  static const String redirectUrl = 'http://localhost:8125/callback';
  static const String scope = 'repo,read:org';

  static Future<GitHub> createGitHubClient() async {
    final authorizationEndpoint =
        Uri.parse('https://github.com/login/oauth/authorize');
    final tokenEndpoint =
        Uri.parse('https://github.com/login/oauth/access_token');

    final grant = oauth2.AuthorizationCodeGrant(
      clientId,
      authorizationEndpoint,
      tokenEndpoint,
      secret: clientSecret,
    );

    final authorizationUrl =
        grant.getAuthorizationUrl(Uri.parse(redirectUrl), scopes: [scope]);

    // Open the authorization URL in a web browser
    await launchUrl(authorizationUrl);

    // Wait for the user to authorize and get the auth code
    // You'll need to implement a way to capture the redirect URL
    String authCode = await getAuthCodeFromRedirect();

    final client = await grant.handleAuthorizationCode(authCode);

    return GitHub(
        auth: Authentication.withToken(client.credentials.accessToken));
  }

  static Future<String> getAuthCodeFromRedirect() async {
    // Implement this method to capture the auth code from the redirect URL
    // This might involve using a local server or deep linking
  }
}
