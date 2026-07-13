# Setup GitHub
You will need a GitHub 
Create a private git repository, initialize it with a README.
Click on you top-right user icon -> Settings -> Developer Settings -> New Fine Grained Token
Select the reporisoty, add the following permissions:
* Contents → Read and write
* Metadata → Read-only

## Write the settings.json file
You need to add and push a settings.json file with the calendars and the syncronization rules:
```json
{
	"calendars": [],
    "sync":[]
}
```

## calendars
Add the configuration for each calendar you want to sync - See the README.md -> Datamodel -> Calendar

## sync jobs
Add the configuration for each sync job - See the README.md -> Datamodel -> Synchronization Job