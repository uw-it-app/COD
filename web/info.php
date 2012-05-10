<?php
$version = '2.2.1';

/****************************************************************************/

# redirect to https if http
if (!isset($_SERVER['HTTPS']) || $_SERVER['HTTPS'] !== 'on') {
    header('Location: https://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'], true, 301);
    exit();
}
header('X-UA-Compatible: IE=Edge,chrome=1');

function pathinfoToHash () {
    $pathinfo = $_SERVER['PATH_INFO'];
    $split = mb_split('/', $pathinfo);
    $out = array();
    for ($x=1; $x<count($split); $x+=2) {
        $key   = preg_replace('/[^a-z0-9_\-]/i', '', urldecode($split[$x]));
        if (isset($split[$x+1])) {
            $out[$key] = preg_replace('/[^a-z0-9_\-]/i', '', urldecode($split[$x+1]));
        } else {
            $out[$key] = NULL;
        }
    }
    return $out;
}
