<?php

class LoginFaultException extends Exception {}
class AINFaultException extends Exception {}

class AVMAHA
{
    const login_path = "/login_sid.lua";
    const aha_path = "/webservices/homeautoswitch.lua";

    private $hostname;
    private $username;
    private $password;

    public function __construct($host, $user, $pass)
    {
        $this->hostname = $host;
        $this->username = $user;
        $this->password = $pass;

        return true;
    }

    private function GetLoginURL()
    {
        $loginurl = "http://" . $this->hostname . self::login_path;
        return $loginurl;
    }

    private function GetAHAURL()
    {
        $ahaurl = "http://" . $this->hostname . self::aha_path;
        return $ahaurl;
    }

    public function GetSwitchState($ain)
    {
        if (!isset($ain))
            throw new AINFaultException;

        $url = $this->GetAHAURL() . '?sid=' . $this->GetSID()."&ain=".rawurlencode($ain);
        $string = chop(@file_get_contents($url."&switchcmd=getswitchstate"));
        $response = $http_response_header[0];
        if (!preg_match("/200\s+OK$/", $response))
            throw new HTTPException();

        return ($string == "1") ? 1 : 0;
    }

    public function SetSwitchState($ain, $val)
    {
        if (!isset($ain))
            throw new AINFaultException;

        $url = $this->GetAHAURL() . '?sid=' . $this->GetSID()."&ain=".rawurlencode($ain);
        $string = chop(@file_get_contents($url."&switchcmd=getswitchstate"));
        $response = $http_response_header[0];
        if (!preg_match("/200\s+OK$/", $response))
            throw new HTTPException();

        $state = ($string == "1") ? 1 : 0;

        if ($state != $val) {
            //execute query
            $cmd = ($val == 1) ? 'setswitchon' : 'setswitchoff';
            $answer = @file_get_contents($url.'&switchcmd='.$cmd);
            $response = $http_response_header[0];
            if (!preg_match("/200\s+OK$/", $response))
                throw new HTTPException();
        } else {
            echo "no need to change state\n";
        }
    }

    public function ListAINs()
    {
        $url = $this->GetAHAURL() . '?sid=' . $this->GetSID();
        $string = chop(@file_get_contents($url . "&switchcmd=getswitchlist"));
        $response = $http_response_header[0];
        if ((preg_match("/200\s+OK$/", $response)) && (strlen($string) > 0))
            return explode(",", $string);
        return array();
    }

    public function QueryAIN($ain)
    {
        if (!isset($ain))
            throw new AINFaultException;

        $data = array("ain" => $ain);
        $url = $this->GetAHAURL() . '?sid=' . $this->GetSID()."&ain=".rawurlencode($ain);

        $string = chop(@file_get_contents($url."&switchcmd=getswitchname"));
        $response = $http_response_header[0];
        if ((preg_match("/200\s+OK$/", $response)) && (strlen($string) > 0))
            $data["name"] = $string;

        $string = chop(@file_get_contents($url."&switchcmd=getswitchpresent"));
        $response = $http_response_header[0];
        if ((preg_match("/200\s+OK$/", $response)) && (strlen($string) > 0))
            $data["present"] = ($string == "1") ? 1 : 0;

        $string = chop(@file_get_contents($url."&switchcmd=getswitchstate"));
        $response = $http_response_header[0];
        if ((preg_match("/200\s+OK$/", $response)) && (strlen($string) > 0))
            $data["state"] = ($string == "1") ? 1 : 0;

        $string = chop(@file_get_contents($url."&switchcmd=getswitchpower"));
        $response = $http_response_header[0];
        if ((preg_match("/200\s+OK$/", $response)) && (strlen($string) > 0))
            $data["power"] = (int)$string;

        $string = chop(@file_get_contents($url."&switchcmd=getswitchenergy"));
        $response = $http_response_header[0];
        if ((preg_match("/200\s+OK$/", $response)) && (strlen($string) > 0))
            $data["energy"] = (int)$string;

        return $data;
    }

    private function GetSID()
    {
        $loginurl = $this->GetLoginURL();
        if (!$this->password) {

            throw new LoginFaultException;
        }

        if (is_null($this->username))
            $this->username = '';

        /* get challenge string */
        $http_response = @file_get_contents($loginurl);
        if (isset($http_response_header[0])) {
            $response = $http_response_header[0];
        } else {
            $response=error_get_last()['message'];
        }

        if (preg_match("/200\s+OK$/", $response)) {
            $xml = simplexml_load_string($http_response);
            $challenge = (string)$xml->Challenge;
            $sid = (string)$xml->SID;
        } else {
            throw new LoginFaultException;
        }

        /* sid is null, got challenge */
        if ((strlen($sid) > 0) && (preg_match("/^[0]+$/", $sid)) && $challenge) {
            $pass = mb_convert_encoding($challenge . "-" . $this->password, "UTF-16LE");
            $md5 = md5($pass);
            $challenge_response = $challenge . "-" . $md5;
            $url = $loginurl . "?username=" . $this->username . "&response=" . $challenge_response;
            $http_response = file_get_contents($url);
            $xml = simplexml_load_string($http_response);
            $sid = (string)$xml->SID;
            if ((strlen($sid) > 0) && !preg_match("/^[0]+$/", $sid)) {
                //is not null, bingo!
                return $sid;
            }
        } else {
            /* use existing sid if $sid matches a hex string */
            if ((strlen($sid) > 0) && (preg_match("/^[0-9a-f]+$/", $sid)))
                return $sid;
        }

        throw new LoginFaultException;
    }
}

?>
