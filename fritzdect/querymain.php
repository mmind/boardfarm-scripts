#!/usr/bin/php
<?php
require_once(dirname(__FILE__)."/avmaha.inc.php");
require_once(dirname(__FILE__)."/cmdbase.inc.php");
require_once(dirname(__FILE__)."/config.inc.php");

$c = new AVMAHA($host, $user, $pass);
$data = $c->QueryAIN("087610266671");
foreach($data as $key => $val)
	echo $key.":".$val."\n";

?>
