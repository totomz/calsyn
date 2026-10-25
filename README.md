claude --resume 2fcb9e28-1190-42ac-84fc-b376b67bd9fe

# calsyn
Sincronizza piu' calendari Outlook e Google Calendar tra loro
In particolare crea degli eventi clone nei rispettivi calendari in modo da:
* permettere agli altri utenti di vedere quando si è disponibili o meno;
* vedere le modifiche su tutti i client connessi, senza dover importare/modificare i calendar visualizzati;
* far funzoinare le notifiche

Questo tool è **self-hosted** e **utilizza le credenziali dell'utente**
Non è necessario registrare una Enterprise Application in Microsoft o in Google Workspace

# General Architecture
La sincronizzazione Outlook e Google avviene tramite degli script che si interfacciano con Apple Calendar.App:
Bisogna creare un Internet Account e sincronizzare ogni calendario in Calendar.app


# How to use
`<todo>`

# Datamodel
## Calendar
Un Calendar `una "connessione" ad un calendar specifico: 
```yaml
calendars:
  - name: "@gmail"
    clone_prefix: "[tom]"
    color: green hire
  - name: "infocert"
    clone_prefix: "[inf]"
    color: blue 
  - name: "luxottica"
    clone_prefix: "[inf]"
    color: violet

```
* `cal_name`: identifica il calendar in Calendar.app
* `clone_prefix`: è il suffisso che viene aggiunto ad ogni clone dell'evento
* `color`: è il colore usato da tutti gli eventi clone

## Synchronization Job
Un job è defined as:

```yaml
sync:
  - name: "totomz -> tutto (no dettagli)"
    source: "@gmail"
    destinations: 
      - infocert
      - luxottica     
    details:
      title: false
      descrription: false
```

* `name`: è un nome descrittivo del sync
* `source`: è il `calendar.name` da cui prendere gli eventi da clonare;
* `destinations`; è l'elenco dei `calendar.name` dove creare gli eventi clone;
* `details`: che campi clonare. Se vuoto gli eventi cloni avranno solo il prefisso `calendar.event_clone_prefix`, altrimenti:
* * `title`: scrive il title/summary dell'evento
* * `description`: scrive la descrizione dell'evento
