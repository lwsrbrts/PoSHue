<?php
session_start();
include('vendor/autoload.php');
use League\OAuth2\Client\Token\AccessToken;

# Crap request filtering.
if (!isset($_POST['access_token']) || 
    !isset($_POST['refresh_token']) ||
    !isset($_POST['expires']) ||
    !preg_match('/^([a-zA-Z0-9]*)$/', $_POST['access_token']) ||
    !preg_match('/^([a-zA-Z0-9]*)$/', $_POST['refresh_token']) ||
    !preg_match('/^([0-9]*)$/', $_POST['expires'])
    ){
    header('Content-Type: application/json;charset=utf-8');
    header($_SERVER["SERVER_PROTOCOL"]." 400 Bad Request"); 
    $data = [ 'error' => 'bad request'];
    echo json_encode($data);
    die();
}
else {
    $accesstoken = htmlentities($_POST['access_token']);
    $refreshtoken = htmlentities($_POST['refresh_token']);
    $expiration = htmlentities($_POST['expires']);

    $provider = new \League\OAuth2\Client\Provider\GenericProvider([
        'clientId'                => 'xxxxxxxxxxxxx',    // The client ID assigned to you by the provider
        'clientSecret'            => 'xxxxxxxxxxxxx',   // The client password assigned to you by the provider
        'redirectUri'             => 'https://www.lewisroberts.com/poshue.php',
        'urlAuthorize'            => 'https://api.meethue.com/oauth2/auth',
        'urlAccessToken'          => 'https://api.meethue.com/oauth2/refresh',
        'urlResourceOwnerDetails' => 'http://brentertainment.com/oauth2/lockdin/resource',
        'appId'          	      => 'poshue',
        'deviceId'                => 'poshue1',
        'deviceName'			  => 'poshue'
    ]);

    $existingAccessToken = new AccessToken([
        'access_token' => $accesstoken, //required
        'refresh_token' => $refreshtoken, // required
        'expires' => $expiration, // required
        ]);

    if ($existingAccessToken->hasExpired()) {
        $newAccessToken = $provider->getAccessToken(
            'refresh_token', ['refresh_token' => $existingAccessToken->getRefreshToken() ]
        );

        // Output to a JSON object so the user/module can do something with it.
        header('Content-Type: application/json;charset=utf-8');
        echo json_encode($newAccessToken, JSON_PRETTY_PRINT);
        
    }
    else {
        // Spit out a JSON encoded error saying the token hasn't expired yet - based on the expiration.
        header('Content-Type: application/json;charset=utf-8');
        header($_SERVER["SERVER_PROTOCOL"]." 424 Failed Dependency");
        $data = [ 'error' => 'not expired'];
        echo json_encode($data);
    }
}

?>