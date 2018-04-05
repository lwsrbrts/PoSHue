<?php
session_start();
include('vendor/autoload.php');

$provider = new \League\OAuth2\Client\Provider\GenericProvider([
    'clientId'                => 'xxxxxxxxxxxx',    // The client ID assigned to you by the provider
    'clientSecret'            => 'xxxxxxxxxxxx',   // The client password assigned to you by the provider
    'redirectUri'             => 'https://www.lewisroberts.com/poshue.php',
    'urlAuthorize'            => 'https://api.meethue.com/oauth2/auth',
    'urlAccessToken'          => 'https://api.meethue.com/oauth2/token',
    'urlResourceOwnerDetails' => 'http://brentertainment.com/oauth2/lockdin/resource',
	'appId'          	      => 'poshue',
	'deviceId'                => 'poshue1',
	'deviceName'			  => 'poshue'
]);

// If we don't have an authorization code then get one
if (!isset($_GET['code'])) {

    // Fetch the authorization URL from the provider; this returns the
    // urlAuthorize option and generates and applies any necessary parameters
    // (e.g. state).
    $authorizationUrl = $provider->getAuthorizationUrl();

    // Get the state generated for you and store it to the session.
    $_SESSION['oauth2state'] = $provider->getState();

    // Redirect the user to the authorization URL.
    header('Location: ' . $authorizationUrl);
    exit;

// Check given state against previously stored one to mitigate CSRF attack
}
elseif (empty($_GET['state']) || ($_GET['state'] !== $_SESSION['oauth2state'])) {

    unset($_SESSION['oauth2state']);
    exit('Invalid state');
}
 else {

    try {

        // Try to get an access token using the authorization code grant.
        $accessToken = $provider->getAccessToken('authorization_code', [
            'code' => $_GET['code']
        ]);

        // We have an access token, which we may use in authenticated
        // requests against the service provider's API.

        
        $PoSHueAccessToken = $accessToken->getToken();
        $PoSHueRefreshToken = $accessToken->getRefreshToken();
        $PoSHueExpirationDate = $accessToken->getExpires();
        $PoSHueExpirationStatus = ($accessToken->hasExpired() ? 'EXPIRED!' : 'Valid (not expired)');


        ?>
<html>
<head>
<title>PoSHue - Philips Hue Remote API Access Tokens</title>
<link rel="stylesheet" type="text/css" href="poshue/css/reset.css">
<link rel="stylesheet" type="text/css" href="poshue/css/style.css">
<script src="poshue/js/clipboard.min.js"></script>
</head>
<body>
<p><img class="logo" src="poshue/img/poshue-logo.png" /></p>
<h1>Your token...</h1>
<p>
The following information is provided by the Philips Hue Remote API and is an access token which allows the PoSHue module (classes) to
interact with your Hue Bridge via the Philips Hue Remote API on your behalf. The process you have just gone through permits this application to access
your Philips Hue Bridge remotely when the Access Token is provided and where there is a username (whitelist entry) also provided.
</p>
<p>Note that I do not have access to your Hue Bridge's usernames/whitelist entries.</p>
<p><b>Absolutely no information</b> about your tokens is retained by this site in <b>any</b> way; including in logs, databases, scraps of paper or any other recording medium.</p>
<h1>Don't panic Mr. Mainwaring, don't panic!</h1>
<p>If you wish to disable your access token, visit the <a href="https://account.meethue.com/apps">Philips Hue Account apps</a> website and click
deactivate next to the PosHue application name.</p>
<h1>The token...</h1>
<p>You should record all of the information below. Especially if you want to use the module to refresh your access token when it expires (usually just 7 days time!).
    The expiration date is represented as a Unix Timestamp. When refreshing the token using the module, you must provide the Unix Timestamp.
</p>
<script>
    new ClipboardJS('.btn');
</script>

<form id="tokens" onsubmit="return false">
<label for="accessToken" class="access-Token">Access Token:</label>
<input id="accesstoken" value="<?php echo $PoSHueAccessToken; ?>">
<button class="btn" data-clipboard-target="#accesstoken">Copy</button>

<label for="refreshToken" class="refresh-Token">Refresh Token:</label>
<input id="refreshtoken" value="<?php echo $PoSHueRefreshToken; ?>">
<button class="btn" data-clipboard-target="#refreshtoken">Copy</button>

<label for="expiredDate" class="expired-Date">Expiration Date:</label>
<input id="expiredate" value="<?php echo $PoSHueExpirationDate ." (". date("Y-m-d H:i:s", $PoSHueExpirationDate).")"; ?>">

<label for="expireStatus" class="expire-Status">Expiration Status:</label>
<input id="expirestatus" value="<?php echo $PoSHueExpirationStatus; ?>">
</form>

<h1>JSON</h1>
<p>The same information as above represented as a JSON object. You can store this in a file for example and read it back in using ConvertFrom-Json.</p>
<pre>
<?php echo json_encode($accessToken, JSON_PRETTY_PRINT); ?>

</pre>

<h1>How do I use this?</h1>
<p>Some example PowerShell code is below but please consult the <a href="https://github.com/lwsrbrts/PoSHue" target="_blank">GitHub project site</a> for more detailed information.</p>
<pre>
Import-Module PoSHue

$RemoteApiAccessToken = '<?php echo $PoSHueAccessToken ?>'

$APIKey = "[obtained from your call to GetNewApiKey()]"

$Bridge = [HueBridge]::new($RemoteApiAccessToken, $UserID, $true)

$Bridge.GetLightNames()

$Light = [HueLight]::new('Hue go 2', $RemoteApiAccessToken, $UserID, $true)
$Light.SwitchHueLight()

$Group = [HueGroup]::new('Office', $RemoteApiAccessToken, $UserID, $true)
$Group.SwitchHueGroup('OFF')
$Group.SwitchHueGroup('ON')
</pre>
</body>
</html>
        <?php


    } catch (\League\OAuth2\Client\Provider\Exception\IdentityProviderException $e) {

        // Failed to get the access token or user details.
        exit($e->getMessage());

    }
}

?>