# calsyn
Synchronizes multiple Outlook and Google Calendar calendars with each other
In particular, it creates clone events in the respective calendars in order to:
* let other users see when you are available or not;
* see the changes on all connected clients, without having to import/modify the displayed calendars;
* make notifications work

This tool is **self-hosted** and **uses the user's credentials**
There is no need to register an Enterprise Application in Microsoft or in Google Workspace

# General Architecture
The Outlook and Google synchronization happens through an EventKit binary that interfaces with Apple Calendar.app:
You need to create an Internet Account and sync every calendar in Calendar.app


# How to use
Clone, build and install.
Install will copy the executable and generate an empty configuration file
```shell
git clone https://github.com/totomz/calsyn
swift build && .build/debug/calsyn install
```

## A simple configuration file
Given these calendar IDs
```shell
$ calsyn calendars
msg=calendar id="Google/AS Roma" 
msg=calendar id=Google/personal
msg=calendar id=Exchange/Job 
msg=calendar id=Exchange/SideJob 
```

This is a sample configuration file
```yaml
# List here all your calendars
calendars:
    # id: same as the one from `calsyn calendars`
  - id: Google/AS Roma    
    # every cloned event will have this prefix 
    clone_prefix: "[roma]"  
  - id: Google/personal
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
# a job can have multiple sources and multiple destinations
# skip the events sync if destination==source 
sync:
  # can be anything
  - name: "clone all jobs to my personal"
    # deletes the events in destinations that have a prefix    
    # among those defined in the sources
    # only used to select the jobs of the `cleanup` command, this tag is ignored by the sync
    # when `true`, delete all the events in every destination 
    # that begin with any prefix defined in sources
    # It is used only by `calsyn cleanup`, ignored by any other command
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
      
      # add my personal events (not the clones)
      - Google/personal
    details:
      # keep it private
      title: false
      description: false
    destinations:
      - Exchange/Job
      - Exchange/SideJob
    
```

## Commands
- `calsyn install`: install as a service and open an empty configuration file with the default editor
- `calsyn calendars`: list the calendar ids
- `calsyn config`: update the config file (~/.config/calsyn/config.yaml)
- `calsyn once`: run a single sync
- `calsyn run`: run as a service and listen for incoming changes. It also runs every 5 minutes as cronjob
- `calsyn cleanup`: delete all cloned events for the sync jobs that have `cleanup: true`. Affects only events in the configured time window

