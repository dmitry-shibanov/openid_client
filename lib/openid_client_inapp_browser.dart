library openid_client.inapp_browser;

import 'dart:async';
import 'dart:ui';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs_launcher;
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:uni_links/uni_links.dart';
import 'openid_client.dart';

export 'openid_client.dart';

final _logger = new Logger("openid_client.inapp_browser");

class Authenticator {
  final Flow flow;

  Authenticator(this.flow);

  Future<Credential> authorize() async {
    final uri = await _browserRequest(this.flow.authenticationUri, this.flow.redirectUri);
    return await flow.callback({
      ...uri.queryParameters,
      ...Uri.splitQueryString(uri.fragment),
    });
  }

  Future logout(IdToken idToken, Uri redirectUri) async {
    final Uri endSessionUri = this.flow.client.issuer.metadata.endSessionEndpoint
        .replace(queryParameters: {
      "id_token_hint": idToken.toCompactSerialization(),
      "post_logout_redirect_uri": redirectUri.toString(),
      "state": this.flow.state
    });
    await _browserRequest(endSessionUri, redirectUri);
  }

  Future<Uri> _browserRequest(Uri pageUri, Uri redirectUri) async {
    final deepLinkCompleter = Completer<Uri>.sync();
    final resumeCompleter = Completer.sync();
    StreamSubscription subscription;
    void _checkDeepLink(String link) {
      if (link == null || !link.startsWith(redirectUri.toString())) {
        return;
      }
      url_launcher.closeWebView();

      _logger.fine("Received browser callback: " + link);
      deepLinkCompleter.complete(Uri.parse(link));
    }

    // Handle callback.
    subscription = getLinksStream().listen(_checkDeepLink, cancelOnError: true);
    SystemChannels.lifecycle.setMessageHandler((message) {
      if (message == AppLifecycleState.resumed.toString()) {
        SystemChannels.lifecycle.setMessageHandler(null);
        resumeCompleter.complete();
      }
    });

    // Open web page.
    _logger.fine("Opening page: " + pageUri.toString());
    custom_tabs_launcher.launch(
      pageUri.toString(),
      option: custom_tabs_launcher.CustomTabsOption(
        enableDefaultShare: false,
        enableUrlBarHiding: true,
        showPageTitle: false,
      ),
    ).catchError((e) {
      _logger.warning("Failed to open page: " + e.toString());
    });
    resumeCompleter.future.then((_) {
      if (!deepLinkCompleter.isCompleted) {
        deepLinkCompleter.completeError(Exception("Canceled"));
      }
    });
    try {
      final uri = await deepLinkCompleter.future;
      await resumeCompleter.future;
      return uri;
    } finally {
      subscription.cancel();
      url_launcher.closeWebView();
    }
  }
}
