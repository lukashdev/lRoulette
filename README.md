# lRoulette - ruletka na kredyty serwerowe

Gracz w nim może dostosować dla siebie wyświetlanie, w hudzie czy na czacie.

Jest możliwość zobaczenia ostatnich 15 kolorów

Są rankingi typu: Wygrane, przegrane, wygrane i przegrane kredyty

Komenda: !ru

Config się znajduje w cfg/sourcemod/lRoulette.cfg

W nim można zmienić maksymalną ilość do postawienia dla Vipa i przeciętnego gracza, flagę Vipa i tag na czacie.

 
Należy dodać do addons/sourcemod/configs/databases.cfg

	"lRoulette"
	{
		"driver"			"mysql"
		"host"				""
		"database"			""
		"user"				""
		"pass"				""
		//"timeout"			"0"
		//"port"			"0"
	}
  
Połączenie z bazą jest wymagane ze względu na rankingi.
