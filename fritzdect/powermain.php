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

$newState = $params["_"][0];

$c = new AVMAHA($host, $user, $pass);
$c->SetSwitchState("087610266671", $newState);

?>
