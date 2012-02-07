<?php
$version = '2.0.0';

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