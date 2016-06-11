<?php

/**
 * Grundlage fuer die Kommandozeilenklasse in cmdbase.
 * Diese hier enthaelt mehr die Grundlegenden Sachen
 * die keine Session etc benoetigen.
 */
class CmdBase
{
  /**
   * Parst das Array der Kommandozeilen Parameter.
   * Dabei koennen durch den Funktionsparameter Standardwerte definiert werden.
   * @param params Array der Default Werte, die von gesetzten Parameter ueberschrieben werden.
   * @return Array der Parameter
   */
  public function ParseParams($params = array())
  {
    $intcnt = 0;
    for($i = 1; $i < $_SERVER["argc"]; $i++)
    {
      //wenn wir einen Parameter mit "--" haben
      if(substr($_SERVER["argv"][$i],0,2) == "--")
      {
        $eqpos = strpos($_SERVER["argv"][$i], "=");
        if($eqpos !== false)
        {
          $pname = substr($_SERVER["argv"][$i],2,$eqpos-2);
          $params[$pname] = substr($_SERVER["argv"][$i], $eqpos+1);
        }
        else
        {
          $pname = substr($_SERVER["argv"][$i],2);
          $params[$pname] = 1;
        }
      }
      //wenn es ein Parameter mit "-" ist
      /// FIXME: hier dann eventuell noch ein mapping auf entsprechende lange Parameter, d.h. -t => --test etc
      elseif(substr($_SERVER["argv"][$i],0,1) == "-")
      {
        //wenn der naechste argv Wert schon wieder ein Parameter ist
        //wird fuer den aktuellen Parameter 1 als Wert angenommen
        //sonst der Wert des naechsten argv Elementes
        if(substr($_SERVER["argv"][$i+1], 0, 1) == "-" || $i+1 >= $_SERVER["argc"])
          $params[substr($_SERVER["argv"][$i],1)] = 1;
        else
        {
          $params[substr($_SERVER["argv"][$i],1)] = $_SERVER["argv"][$i+1];
          $i++;
        }
      }
      //ansonsten setzen wir den naechsten Basisparameter
      else
      {
        $params["_"][$intcnt] = $_SERVER["argv"][$i];
        $intcnt++;
      }
    }
    return $params;
  }

  /**
   * Abstraktion von proc_open und Konsorten um Daten an ein Programm zu uebergeben und die Ausgabe zurueckzuliefern.
   * @param cmd auszufuehrendes Programm
   * @param Input Eingabedaten die per Pipe an das Programm uebergeben werden.
   * @return Ausgabe des Programms.
   */
  public static function ProcIO($cmd, $Input)
  {
    //Programm oeffnen
    $descspec = array(0 => array("pipe", "r"), 1 => array("pipe", "w"));
    $pp = proc_open($cmd, $descspec, $pipes);

    //den Input-Text an das Programm uebergeben
    fwrite($pipes[0], $Input);
    fclose($pipes[0]);

    //das Ergebnis holen
    $content = stream_get_contents($pipes[1]);
    fclose($pipes[1]);

    //Programm schliessen und Ergebniss ausliefern
    proc_close($pp);
    return $content;
  }

}

?>
