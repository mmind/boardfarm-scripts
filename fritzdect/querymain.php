#!/usr/bin/php5
<?php
require_once(dirname(__FILE__)."/avmaha.inc.php");
require_once(dirname(__FILE__)."/cmdbase.inc.php");
require_once(dirname(__FILE__)."/config.inc.php");

$c = new AVMAHA($host, $user, $pass);
print_r($c->QueryAIN("087610266671"));

?>
