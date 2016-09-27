#!/usr/bin/php5
<?php
require_once(dirname(__FILE__)."/avmaha.inc.php");
require_once(dirname(__FILE__)."/cmdbase.inc.php");
require_once(dirname(__FILE__)."/config.inc.php");

$params = CmdBase::ParseParams(array());
if (!isset($params["_"])) {
    echo "missing new state\n";
    exit;
}
if (count($params["_"]) > 1) {
    echo "to many params\n";
    exit;
}

$ain = $params["_"][0];

$c = new AVMAHA($host, $user, $pass);
$data = $c->QueryAIN($ain);
foreach($data as $key => $val)
	echo $key.":".$val."\n";

?>
