# Setup Google
For each account where you want to sync a calendar:
1. Create a new Google Sheet
2. Go to `Extensions` -> `App Scripts` and paste the contents of `google-sync.gs`
3. Add the configu variables or creat Scripts Attributes to store your private git repo & token
4. Save
5. Add 2 triggers (Triggers -> Add New Trigger): Every 5 minutes and when the calendar change (this shuould make it faster for other calendars to pick the changes)
