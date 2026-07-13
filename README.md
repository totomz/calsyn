# calsyn
Sincronizza piu' calendari Outlook e Google Calendar tra loro
In particolare crea degli eventi clone nei rispettivi calendari in modo da:
* permettere agli altri utenti di vedere quando si è disponibili o meno;
* vedere le modifiche su tutti i client connessi, senza dover importare/modificare i calendar visualizzati;
* far funzoinare le notifiche

Questo tool è **self-hosted** e **utilizza le credenziali dell'utente**
Non è necessario registrare una Enterprise Application in Microsoft o in Google Workspace

# General Architecture
La sincronizzazione Outlook e Google avviene tramite dei "tools":
* per Google, ogni Google Calendar è gestito da un Google Sheet + AppScript nel suo stesso account;
* per Outlook usiamo [outlook-cli](https://github.com/yusufaltunbicak/outlook-cli) 

I vari agent leggono e scrivono i calendar da sincronizzare da vari file in un repository Github privato dell'utente.


# How to use
Il setup è un pizzico laborioso, purtroppo, ma non dovrebbe richiedere piu' di 15 minuti:
1. [Crea un GtiHub repo privato](docs/setup-github.md) vuoto;
2. Aggiungi il file `settings.json` con i calendar da sincronizzare;
3. Aggiungici lo script `calsync.sh`;
4. Crea un [Google Sheet + AppScript](docs/setup-google.md) per ogni calendar Google da sincronizzare; 
5. Installa [outlook-cli](docs/setup-oulook) cli;

## Requirements
Per funzionar,e bisogna installare e configurare un paio di cosette
- [A gitHub Repo](docs/setup-github.md)
- [outlook-cli](https://github.com/yusufaltunbicak/outlook-cli) <-- TODO link alla doc 
- [Google AppScript](docs/setup-google.md)

# Datamodel
## Calendar
Un Calendar `una "connessione" ad un calendar specifico: 
```json
		{
			"name": "totomz",
			"type": "google",
			"profile": "totomz@gmail.com",
			"event_clone_prefix": "[tom]"
		}
```
* `name`: identifica univocamente un calendar nei job di sync; duplica effettivamente il `profile`
* `type`: self-explanatory, o `google` o `outlook`
* `profile`: 
* * se `type=google`: è il calendar id rappresentato da questa connessione (cioè, gli eventi vengono letti da questo calendar e scritti da questo calendar). Lo trovi in Google Calnedar -> Seleziona il caldendar -> Settings -> cerca "Integrate calendar"
* * se `type=outlook`: è il nome del profilo outlook da usare

## Synchronization Job
Un job è defined as:

```json
{
	"job": "totomz -> tutto (no dettagli)",
	"sources": [
		"totomz"
	],
	"destinations": [
		"croccocode",
		"bob"
	],
	"details":[
        "title",
        "description"
    ]
}
```

* `job`: è un nome descrittivo del sync
* `sources`: è l'elenco dei `calendar.name` da cui prendere gli eventi da clonare;
* `destinations`; è l'elenco dei `calendar.name` dove creare gli eventi clone;
* `details`: che campi clonare. Se vuoto gli eventi cloni avranno solo il prefisso `calendar.event_clone_prefix`, altrimenti:
* * `title`: scrive il title/summary dell'evento
* * `description`: scrive la descrizione dell'evento

## Git repository
Il repository git contiene questi files:
* `settings.json`: configurazioni delle connessioni ai calendar e delle regole di sync

Per ogni calendar:
* `<profile>-events.json`: un file con tutti gli eventi letti da quel calendar e che andranno ad essere clonati con questo formato:

```json
[
	{
		"title": "meeting",
        "from": "2026-07-15 10:00",
        "to": "2026-07-15 12:00",
        "description": "multi\nline\navailable"
	}
]
```
* `from` e `to` sono nel formato YYYY-MM-DD HH:MM in UTC

## Come funziona il tutto
Ogni calendar ha un attributo `event_clone_prefix`. 
Ogni calendario seleziona per la copia solamente gli eventi che non iniziano per nessuno dei prefix configurati.
Tutti gli eventi cloni hanno come prefisso il `event_clone_prefix`.

Ogni 5 minuti un App Script (google) o un cron-job locale (outlook)
* sovrascrive il file `<profile>-events.json` con tutti gli eventi del calendar (sono ignorati tutti gli eventi che hanno come prefisso del title/summary uno qualsiasi dei `[]calendar.event_clone_prefix` definiti in `settings.json`)
* Per ogni job dove è registrato tra le `destination`
* * per ogni source
* * * carica tutti gli eventi dal file `-events.json` quella source, calcolandone l'hash (vedi sotto)
* * * cerca tutti gli eventi gia esistenti che hanno quel prefix, now() + 14 giorni
* * * per ogni evento gia nel calendar, vede se esiste un evento nel file con lo stesos hash (strippato del prefix). Se non esiste lo cancella dal calendar, se esiste salta, e lo leva dalla lista degli eventi letti dal file sorgente;
* * * per ogni evento rimasto nella lista del file sorgente, crea l'evento (aggiungendo il prefix)

### Hash
L'hash identifica univocamente un evento clone ed è calcolato **solo sui campi effettivamente clonati**, cioè dopo aver applicato il filtro `job.details`:

```
hash = sha1(cloned_title + "|" + from + "|" + to + "|" + cloned_description)
```

dove `cloned_title` e `cloned_description` sono stringhe vuote se il rispettivo campo non è incluso in `job.details`.
Se l'hash fosse calcolato sempre su tutti i campi dell'evento sorgente, un job che non clona la description (o con `details` vuoto) produrrebbe cloni il cui hash non corrisponde mai a quello calcolato dal file, causando un delete+create di tutti gli eventi ad ogni ciclo.

