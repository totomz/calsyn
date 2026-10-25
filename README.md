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
Clone, build and install.
Install will copy the executable and generate an empty configuration file
```shell
git clone github.com/totomz/calsyn
swift build && .build/debug/calsyn install
```

## A simple configuration file
Given these calendar IDs
```shell
$ calsyn calendar
msg=calendar id="Google/AS Roma" 
msg=calendar id=id=Google/personal
msg=calendar id=id=Exchange/Job 
msg=calendar id=id=Exchange/SideJob 
```

This is a sample configuration file
```yaml
# List here all your calendars
calendars:
    # id: same as the one from `calsyn calendars`
  - id: Google/AS Roma    
    # every cloned event will have this prefix 
    clone_prefix: "[roma]"  
  - id: id=Google/personal
    clone_prefix: "[me]"
  - id: Exchange/Job
    clone_prefix: "[job]"
  - id: Exchange/SideJob
    clone_prefix: "[side]"  
 
window:
  # sync events in the past days
  past_days: 0
  # sync events in the next days
  future_days: 8

# sync job 
# a job can have multiple sources and multiple destination
# skip the events sync if destination==source 
sync:
  # can be anything
  - name: "clone all jobs to my personal"
    # cancella gli eventi in destinations che hanno un prefix    
    # tra quelli definiti nelle sources
    # serve solo a scegliere i job del comando `cleanup`, questo tag è ignorato dal sync
    # when `true`, delete all the events in every destinations 
    # that begins with any prefix defined in sources
    # It is used only by `calsync cleanup`, ignored by any other command
    # cleanup: true
    sources: 
      - Google/AS Roma
      - Exchange/Job
      - Exchange/SideJob
    details:
      # copy the event title in the clones
      title: true
      # copy the event description in the clones
      description: true
    destinations:
      - Google/personal
  
  - name: "sync the jobs"    
    sources:
      - Exchange/Job
      - Exchange/SideJob  
      
      # I\ll add also my personal events (not the clones)
      - Google/@gMail
    details:
      # keep it private
      title: false
      description: false
    destinations:
      - Exchange/Job
      - Exchange/SideJob
    
```

## Commands
- `calsyn install`: generate a default config and install as a service
- `calsyn calendars`: list the calendars id
- `calsyn config`: update the config file (~/.config/calsyn.yaml)
- `calsyn once`: run a single sinc
- `calsyn run`: run as a service and listen for incoming changes. It also run every 5 minutes as cronjob
- `calsyn cleanup`: delete al coloned events

