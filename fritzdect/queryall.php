#!/usr/bin/php
<?php
require_once(dirname(__FILE__)."/avmaha.inc.php");
require_once(dirname(__FILE__)."/cmdbase.inc.php");
require_once(dirname(__FILE__)."/config.inc.php");

$c = new AVMAHA($host, $user, $pass);
foreach($c->ListAINs() as $ain) {
	$data = $c->QueryAIN($ain);
	foreach($data as $key => $val)
		echo $key.":".$val."\n";
}

?>
