<?php
/**
 * OS Archers — Records Feed Proxy
 * Fetches the Archery Records XML feed server-side to avoid CORS issues.
 * Place this file at: /proxy/records.php on the osarchers.co.uk server.
 */

$allowed_origins = [
    'https://www.osarchers.co.uk',
    'https://osarchers.co.uk',
];

$origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '';

if (in_array($origin, $allowed_origins)) {
    // Cross-origin fetch from our own site pages
    header('Access-Control-Allow-Origin: ' . $origin);
} elseif ($origin === '') {
    // Direct browser request (no Origin header) — allow for testing
    // This covers visiting /proxy/records.php directly in a browser
} else {
    // Block requests from other domains
    http_response_code(403);
    exit('Forbidden');
}

header('Content-Type: application/xml; charset=utf-8');
header('Cache-Control: public, max-age=300'); // Cache for 5 minutes

$feed_url = 'https://archery-records.net/feeds/xml?method=clubrecords&uid=331b3400-d495-406c-a7a2-f3040913dcef';

$context = stream_context_create([
    'http' => [
        'timeout'       => 10,
        'user_agent'    => 'OSArchers/1.0 (osarchers.co.uk)',
        'ignore_errors' => true,
    ],
    'ssl' => [
        'verify_peer'      => true,
        'verify_peer_name' => true,
    ],
]);

$xml = @file_get_contents($feed_url, false, $context);

if ($xml === false || empty($xml)) {
    http_response_code(502);
    echo '<?xml version="1.0" encoding="utf-8"?><e>Unable to fetch records feed</e>';
    exit;
}

echo $xml;