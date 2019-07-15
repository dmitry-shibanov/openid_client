# openid_client

Library for working with OpenID Connect and implementing clients.

It currently supports these features:

* discover OpenID Provider metadata
* parsing and validating id tokens
* basic tools for implementing implicit, authorization code and hybrid flow

Besides authentication providers that support OpenID Connect, this 
library can also work with other authentication providers supporting
oauth2, like Facebook. For these providers, some features (e.g. discovery and id tokens) 
will not work. You should define the metadata for those providers manually, except
for Facebook, which is predefined in the library.

## Usage

A simple usage example:

```dart
import 'package:openid_client/openid_client.dart';

main() async {

  // print a list of known issuers
  print(Issuer.knownIssuers);

  // discover the metadata of the google OP
  var issuer = await Issuer.discover(Issuer.google);
  
  // create a client
  var client = new Client(issuer, "client_id", "client_secret");
  
  // create a credential object from authorization code
  var c = client.createCredential(code: "some received authorization code");

  // or from an access token
  c = client.createCredential(accessToken: "some received access token");

  // or from an id token
  c = client.createCredential(idToken: "some id token");

  // get userinfo
  var info = await c.getUserInfo();
  print(info.name);
  
  // get claims from id token if present
  print(c.idToken?.claims?.name);
  
  // create an implicit authentication flow
  var f = new Flow.implicit(client);
  
  // or an explicit flow
  f = new Flow.authorizationCode(client);
  
  // set the redirect uri
  f.redirectUri = Uri.parse("http://localhost");
  
  // do something with the authentication url
  print(f.authenticationUrl);
  
  // handle the result and get a credential object
  c = await f.callback({
    "code": "some code",
  });
  
  // validate an id token
  var violations = await c.validateToken();
}

```

### Usage example on flutter

```dart
// import the inapp_browser version
import 'package:openid_client/openid_client_inapp_browser.dart';

Future<Credential> authenticate(Uri uri, String clientId, String clientSecret, List<String> scopes, Uri redirectUri) async {
    final issuer = await Issuer.discover(uri);
    final client = Client(issuer, clientId, clientSecret);
    final flow = Flow.hybrid(client)
      ..scopes.addAll(scopes)
      ..redirectUri = redirectUri;
    final authenticator = Authenticator(flow);
    return await authenticator.authorize();
}
```
